<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\Shop;
use App\Models\Transaction;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Support\Facades\Mail;
use App\Mail\SendOtpMail;

class AuthController extends Controller
{
    /**
     * Chức năng: Đăng ký tài khoản người dùng mới và khởi tạo hồ sơ Shop nếu được yêu cầu.
     * Tham số đầu vào: Request $request (name, email, password, role).
     * Giá trị trả về: JSON chứa mã token truy cập và thông tin người dùng.
     */
    public function register(Request $request) {
        $request->validate([
            'name'     => 'required|string|max:255',
            'email'    => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:8',
            'role'     => 'required|in:customer,shop',
        ]);

        return DB::transaction(function () use ($request) {
            // Khởi tạo người dùng mới, mặc định role luôn là 'customer' để Admin kiểm duyệt sau
            $user = User::create([
                'name'     => $request->name,
                'email'    => $request->email,
                'password' => Hash::make($request->password),
                'role'     => 'customer',
                'status'   => 'active',
            ]);

            // Nếu người dùng chọn đăng ký làm người bán, tạo thêm bản ghi Shop ở trạng thái chờ duyệt
            if ($request->role === 'shop') {
                Shop::create([
                    'user_id'           => $user->id,
                    'name'              => $request->name . ' Store',
                    'slug'              => Str::slug($request->name . ' Store') . '-' . time(),
                    'balance'           => 0,
                    'warehouse_address' => 'Chưa cập nhật',
                    'status'            => 'pending',
                ]);
            }

            // Tạo token truy cập để người dùng có thể đăng nhập ngay sau khi ký
            $token = $user->createToken('auth_token')->plainTextToken;

            return response()->json([
                'success'      => true,
                'access_token' => $token,
                'user'         => $user->load('shop'),
                'message'      => $request->role === 'shop'
                    ? 'Đăng ký thành công! Đơn mở shop đang chờ phê duyệt.'
                    : 'Đăng ký thành công!'
            ], 201);
        });
    }

    /**
     * Chức năng: Xác thực thông tin đăng nhập và cấp quyền truy cập.
     * Tham số đầu vào: Request $request (email, password).
     * Giá trị trả về: JSON chứa token truy cập hoặc thông báo lỗi nếu thất bại.
     */
    public function login(Request $request)
    {
        $request->validate([
            'email' => 'required|email',
            'password' => 'required',
        ]);

        $user = User::where('email', $request->email)->first();

        // Kiểm tra sự tồn tại của người dùng và tính chính xác của mật khẩu đã mã hóa
        if (!$user || !Hash::check($request->password, $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Thông tin đăng nhập không chính xác.'
            ], 401);
        }

        // Chặn quyền truy cập nếu tài khoản đang bị Admin khóa
        if ($user->status === 'blocked') {
            return response()->json([
                'success' => false,
                'message' => 'Tài khoản của bạn hiện đang bị khóa.'
            ], 403);
        }

        // Xóa các token cũ để tránh lãng phí tài nguyên và tạo token mới cho phiên làm việc này
        $user->tokens()->delete();
        $token = $user->createToken('auth_token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Đăng nhập thành công.',
            'access_token' => $token,
            'user' => $user->load('shop')
        ]);
    }

    /**
     * Chức năng: Lấy thông tin chi tiết của người dùng đang đăng nhập.
     * Tham số đầu vào: Request $request (chứa thông tin xác thực từ middleware).
     * Giá trị trả về: JSON chứa dữ liệu User kèm thông tin Shop và Địa chỉ liên kết.
     */
    public function profile(Request $request)
    {
        return response()->json([
            'success' => true,
            'user' => $request->user()->load(['shop', 'addresses'])
        ]);
    }

    /**
     * Chức năng: Cập nhật thông tin cá nhân và quản lý tệp tin ảnh đại diện.
     * Tham số đầu vào: Request $request (name, phone, avatar file).
     * Giá trị trả về: JSON chứa dữ liệu người dùng sau khi đã cập nhật thành công.
     */
    public function updateProfile(Request $request)
    {
        $user = $request->user();

        $request->validate([
            'name'   => 'sometimes|string|max:255',
            'phone'  => ['sometimes', 'string', Rule::unique('users')->ignore($user->id)],
            'avatar' => 'nullable|image|mimes:jpeg,png,jpg|max:2048',
        ]);

        return DB::transaction(function () use ($request, $user) {
            $updateData = $request->only(['name', 'phone']);

            // Kiểm tra và xử lý nếu người dùng có tải lên tệp ảnh mới
            if ($request->hasFile('avatar')) {
                // Xóa tệp ảnh cũ khỏi ổ đĩa để giải phóng dung lượng lưu trữ trên server
                if ($user->avatar && \Storage::disk('public')->exists($user->avatar)) {
                    \Storage::disk('public')->delete($user->avatar);
                }

                // Lưu trữ ảnh mới vào thư mục 'avatars' trong ổ đĩa public
                $path = $request->file('avatar')->store('avatars', 'public');
                $updateData['avatar'] = $path;
            }

            $user->update($updateData);

            // Đồng bộ lại dữ liệu Model với cơ sở dữ liệu để đảm bảo trả về thông tin mới nhất
            $user->refresh();

            return response()->json([
                'success' => true,
                'message' => 'Cập nhật thành công!',
                'user'    => $user->load(['shop', 'addresses'])
            ]);
        });
    }

    /**
     * Chức năng: Khởi tạo mã OTP để xác thực quên mật khẩu và thực hiện gửi mail.
     * Tham số đầu vào: Request $request (email).
     * Giá trị trả về: JSON thông báo trạng thái gửi mã (kèm mã debug nếu mail lỗi).
     */
    public function sendOtp(Request $request)
    {
        $request->validate(['email' => 'required|email|exists:users,email']);

        $otp = rand(100000, 999999);
        $user = User::where('email', $request->email)->first();

        // Cập nhật mã xác thực và thời hạn hiệu lực (10 phút) vào bản ghi người dùng
        $user->update([
            'otp_code' => $otp,
            'otp_expires_at' => now()->addMinutes(10)
        ]);

        try {
            // Thực hiện gọi class Mail để gửi thư chứa mã OTP đến người dùng
            if (class_exists(\App\Mail\SendOtpMail::class)) {
                 \Illuminate\Support\Facades\Mail::to($user->email)->send(new \App\Mail\SendOtpMail($otp));
            } else {
                 throw new \Exception("Chưa tạo file SendOtpMail.php rồi Tâm ơi!");
            }

            return response()->json([
                'success' => true,
                'message' => 'Mã OTP đã gửi vào Email của ông.'
            ]);
        } catch (\Exception $e) {
            // Cơ chế dự phòng: Nếu cấu hình SMTP lỗi, vẫn trả về success kèm mã OTP để ông có thể tiếp tục test bài tập
            return response()->json([
                'success' => true,
                'message' => 'Lỗi gửi mail thật, dùng mã debug nhé: ' . $e->getMessage(),
                'debug_otp' => $otp
            ]);
        }
    }

    /**
     * Chức năng: Hủy bỏ token truy cập hiện tại để kết thúc phiên đăng nhập.
     * Tham số đầu vào: Request $request.
     * Giá trị trả về: JSON thông báo đăng xuất thành công.
     */
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();
        return response()->json(['success' => true, 'message' => 'Đã đăng xuất.']);
    }

    /**
     * Chức năng: Thực hiện thay đổi mật khẩu mới dựa trên mã xác thực OTP đã cấp.
     * Tham số đầu vào: Request $request (email, otp_code, password, password_confirmation).
     * Giá trị trả về: JSON kết quả thay đổi mật khẩu.
     */
    public function resetPassword(Request $request)
    {
        $request->validate([
            'email'    => 'required|email|exists:users,email',
            'otp_code' => 'required',
            'password' => 'required|string|min:8|confirmed',
        ]);

        $user = User::where('email', $request->email)
                    ->where('otp_code', $request->otp_code)
                    ->first();

        // Kiểm tra sự trùng khớp của email và mã OTP
        if (!$user) return response()->json(['success' => false, 'message' => 'Yêu cầu không hợp lệ.'], 400);

        // Lưu mật khẩu mới đã băm và xóa bỏ dữ liệu OTP sau khi sử dụng xong để bảo mật
        $user->update([
            'password' => Hash::make($request->password),
            'otp_code' => null,
            'otp_expires_at' => null
        ]);

        return response()->json(['success' => true, 'message' => 'Đổi mật khẩu thành công!']);
    }

    /**
     * Chức năng: Kiểm tra tính hợp lệ và thời hạn của mã OTP người dùng cung cấp.
     * Tham số đầu vào: Request $request (email, otp_code).
     * Giá trị trả về: JSON thông báo kết quả xác thực.
     */
    public function verifyOtp(Request $request)
    {
        $request->validate([
            'email'    => 'required|email|exists:users,email',
            'otp_code' => 'required',
        ]);

        // Xác thực mã OTP đồng thời kiểm tra điều kiện thời gian hết hạn (Expires At)
        $user = User::where('email', $request->email)
                    ->where('otp_code', $request->otp_code)
                    ->where('otp_expires_at', '>', now())
                    ->first();

        if (!$user) {
            return response()->json(['success' => false, 'message' => 'Mã xác thực không đúng hoặc đã hết hạn.'], 400);
        }

        return response()->json(['success' => true, 'message' => 'Xác thực thành công.']);
    }
}
