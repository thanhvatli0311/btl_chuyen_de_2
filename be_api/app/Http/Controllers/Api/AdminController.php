<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\{Shop, Phone, Transaction, User, Notification};
use App\Services\FCMService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Log;



class AdminController extends Controller
{
    /**
     * Chức năng: Lấy các số liệu thống kê tổng quan cho bảng điều khiển của Admin.
     * Tham số đầu vào: Không có.
     * Giá trị trả về: JSON chứa tổng doanh thu sàn, doanh thu hệ thống, số shop hoạt động, người dùng mới và lệnh rút tiền chờ duyệt.
     */
    public function getDashboardStats()
    {
        try {
            $today = \Carbon\Carbon::today();

            // Tính toán GMV: Tổng giá trị tiền từ các giao dịch bán hàng thành công trên toàn hệ thống
            $totalSales = (double) \App\Models\Transaction::where('type', 'sale_revenue')->sum('amount');

            return response()->json([
                'success' => true,
                'data' => [
                    // Tổng doanh thu thực tế của tất cả các cửa hàng cộng lại
                    'total_shop_revenue' => $totalSales,

                    // Doanh thu mà hệ thống thu về (Phí sàn cố định 5% trên mỗi giao dịch)
                    'total_platform_revenue' => $totalSales * 0.05,

                    // Đếm tổng số lượng gian hàng đã qua kiểm duyệt và đang hoạt động
                    'active_shops' => \App\Models\Shop::where('status', 'approved')->count(),

                    // Đếm số lượng tài khoản mới đăng ký trong ngày hôm nay
                    'new_users_today' => \App\Models\User::whereDate('created_at', $today)->count(),

                    // Đếm các yêu cầu rút tiền đang ở trạng thái chờ Admin xử lý (chưa có mã tham chiếu)
                    'pending_withdraws' => \App\Models\Transaction::where('type', 'withdraw')
                        ->whereNull('reference_id')
                        ->count(),
                ]
            ]);
        } catch (\Exception $e) {
            // Xử lý ngoại lệ nếu có lỗi trong quá trình truy vấn cơ sở dữ liệu
            return response()->json([
                'success' => false,
                'message' => 'Lỗi thống kê: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Chức năng: Lấy danh sách các tin đăng điện thoại đang chờ kiểm duyệt.
     * Tham số đầu vào: Không có.
     * Giá trị trả về: JSON chứa danh sách điện thoại có trạng thái 'inactive' kèm thông tin Shop chủ quản.
     */
    public function getPendingPhones()
    {
        // Lấy các máy chưa kích hoạt, nạp kèm dữ liệu Shop và sắp xếp mới nhất lên đầu
        $phones = Phone::where('status', 'inactive')->with('shop')->latest()->get();
        return response()->json(['success' => true, 'data' => $phones]);
    }

    /**
     * Chức năng: Phê duyệt một tin đăng điện thoại để hiển thị lên sàn.
     * Tham số đầu vào: $id (ID của điện thoại cần duyệt).
     * Giá trị trả về: JSON thông báo kết quả phê duyệt thành công.
     */
    public function approvePhone($id)
    {
        // Tìm bản ghi điện thoại, nếu không thấy sẽ tự động báo lỗi 404
        $phone = Phone::findOrFail($id);
        // Cập nhật trạng thái sang 'active' để máy bắt đầu xuất hiện trên trang chủ App
        $phone->update(['status' => 'active']);
        return response()->json(['success' => true, 'message' => 'Đã duyệt tin đăng!']);
    }

    /**
     * Chức năng: Phát thông báo nội bộ từ Admin tới toàn bộ người dùng trên hệ thống.
     * Đặc điểm: Chỉ lưu vào Database, không sử dụng dịch vụ đẩy tin bên ngoài (FCM).
     * Tham số đầu vào: Request $request (title, content).
     */
    public function sendBroadcast(Request $request)
    {
        // 1. Xác thực nội dung thông báo
        $request->validate([
            'title' => 'required|string|max:255',
            'content' => 'required|string',
        ]);

        try {
            DB::beginTransaction();

            // 2. Lấy danh sách ID của tất cả người dùng hiện có trên hệ thống
            $userIds = User::pluck('id');

            if ($userIds->isEmpty()) {
                return response()->json(['success' => false, 'message' => 'Không có người dùng nào để gửi!']);
            }

            // 3. Chuẩn bị dữ liệu để chèn hàng loạt (Tối ưu hiệu năng hơn dùng vòng lặp create)
            $notifications = [];
            $now = now();

            foreach ($userIds as $id) {
                $notifications[] = [
                    'user_id'    => $id,
                    'title'      => $request->title,
                    'content'    => $request->content,
                    'type'       => 'system_broadcast',
                    'is_read'    => false,
                    'created_at' => $now,
                    'updated_at' => $now,
                ];
            }

            // 4. Thực hiện chèn dữ liệu vào bảng notifications
            // Chia nhỏ mảng nếu số lượng user quá lớn (ví dụ mỗi đợt 500 bản ghi) để tránh lỗi SQL
            foreach (array_chunk($notifications, 500) as $chunk) {
                Notification::insert($chunk);
            }

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Đã phát thông báo nội bộ tới ' . $userIds->count() . ' người dùng.'
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Lỗi phát thông báo: ' . $e->getMessage()
            ], 500);
        }
    }


    /**
     * Chức năng: Lấy danh sách các Shop hiện có trên sàn.
     * Tham số đầu vào: Request $request (có thể chứa tham số status để lọc).
     * Giá trị trả về: JSON chứa danh sách các Shop đã lọc theo điều kiện.
     */
    public function getShops(Request $request)
    {
        $status = $request->query('status');
        $query = \App\Models\Shop::query();

        // Nếu người dùng có gửi tham số lọc trạng thái (ví dụ: ?status=pending)
        if ($status) {
            $query->where('status', $status);
        }

        return response()->json([
            'success' => true,
            'data' => $query->latest()->get()
        ]);
    }

    /**
     * Chức năng: Thay đổi trạng thái hoạt động của một Shop (Duyệt, Khóa, v.v.).
     * Tham số đầu vào: Request $request (chứa status mới), $id (ID của Shop).
     * Giá trị trả về: JSON thông báo kết quả cập nhật trạng thái.
     */
    public function updateShopStatus(Request $request, $id)
    {
        // Kiểm tra tính hợp lệ của trạng thái mới gửi lên
        $request->validate(['status' => 'required|in:pending,approved,blocked']);

        $shop = Shop::with('user')->findOrFail($id);
        $shop->update(['status' => $request->status]);

        // Xử lý logic đồng bộ quyền hạn: Nếu duyệt Shop thành công, nâng quyền User lên thành 'shop'
        if ($request->status === 'approved') {
            $shop->user->update(['role' => 'shop']);
        }
        // Nếu bị khóa, hạ quyền User về 'customer' để tước quyền truy cập kênh người bán
        elseif ($request->status === 'blocked') {
            $shop->user->update(['role' => 'customer']);
        }

        return response()->json([
            'success' => true,
            'message' => 'Đã cập nhật trạng thái Shop thành: ' . $request->status
        ]);
    }

    /**
     * Chức năng: Lấy dữ liệu báo cáo doanh thu theo từng ngày trong một khoảng thời gian.
     * Tham số đầu vào: Request $request (start_date, end_date).
     * Giá trị trả về: JSON chứa mảng dữ liệu gồm ngày, tổng GMV và tiền hoa hồng thu được.
     */
    public function getDailyRevenue(Request $request)
    {
        try {
            // Mặc định lấy dữ liệu trong 7 ngày gần nhất nếu không truyền ngày cụ thể
            $start = $request->query('start_date', now()->subDays(7)->toDateString());
            $end = $request->query('end_date', now()->toDateString());

            // Truy vấn và tính toán doanh thu gộp theo từng ngày
            $stats = Transaction::where('type', 'sale_revenue')
                ->whereBetween('created_at', [$start . ' 00:00:00', $end . ' 23:59:59'])
                ->selectRaw("
                    DATE(created_at) as date,
                    SUM(amount) as total_gmv,
                    SUM(amount) * 0.05 as commission
                ")
                ->groupByRaw('DATE(created_at)')
                ->orderBy('date', 'ASC')
                ->get();

            return response()->json(['success' => true, 'data' => $stats]);
        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * Chức năng: Xếp hạng các Shop dựa trên tổng doanh thu bán hàng.
     * Tham số đầu vào: Không có.
     * Giá trị trả về: JSON chứa danh sách các Shop đã duyệt kèm theo tổng số tiền bán được.
     */
    public function getShopRankings() {
        try {
            // Chỉ xếp hạng những shop đang hoạt động bình thường
            $rankings = Shop::where('status', 'approved')
                // Tính tổng cột amount từ bảng giao dịch của mỗi shop với điều kiện là doanh thu bán hàng
                ->withSum(['transactions as revenue' => function($query) {
                    $query->where('type', 'sale_revenue');
                }], 'amount')
                ->orderByDesc('revenue')
                ->get();

            return response()->json(['success' => true, 'data' => $rankings]);
        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * Chức năng: Lấy toàn bộ lịch sử giao dịch của một Shop cụ thể phục vụ mục đích kiểm soát.
     * Tham số đầu vào: $shopId (ID của Shop cần xem).
     * Giá trị trả về: JSON chứa dữ liệu giao dịch được phân trang (20 bản ghi mỗi trang).
     */
    public function getIndividualShopTransactions(Request $request, $shopId) {
        $shop = Shop::findOrFail($shopId);
        // Lấy danh sách giao dịch dựa trên UserID liên kết với Shop đó
        $transactions = Transaction::where('user_id', $shop->user_id)
            ->latest()
            ->paginate(20);
        return response()->json(['success' => true, 'data' => $transactions]);
    }

    /**
     * Chức năng: Phân tích chi tiết doanh thu và giao dịch gần đây của một Shop.
     * Tham số đầu vào: $shopId, start_date, end_date.
     * Giá trị trả về: JSON chứa dữ liệu vẽ biểu đồ doanh thu và 20 giao dịch mới nhất.
     */
    public function getShopDetailAnalytics(Request $request, $shopId)
    {
        try {
            $shop = \App\Models\Shop::findOrFail($shopId);
            $start = $request->query('start_date');
            $end = $request->query('end_date');

            // Xử lý dữ liệu phục vụ hiển thị biểu đồ biến động doanh thu theo ngày
            $chart = \App\Models\Transaction::where('user_id', $shop->user_id)
                ->where('type', 'sale_revenue')
                ->whereBetween('created_at', [$start . ' 00:00:00', $end . ' 23:59:59'])
                ->selectRaw("DATE(created_at) as date, SUM(amount) as total_gmv")
                ->groupByRaw('DATE(created_at)')
                ->get();

            // Lấy nhanh 20 giao dịch mới nhất để Admin theo dõi dòng tiền của Shop
            $transactions = \App\Models\Transaction::where('user_id', $shop->user_id)
                ->latest()->take(20)->get();

            return response()->json([
                'success' => true,
                'data' => ['chart' => $chart, 'transactions' => $transactions]
            ]);
        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

    /**
     * Chức năng: Lấy danh sách tất cả người dùng trên toàn hệ thống.
     * Tham số đầu vào: Không có.
     * Giá trị trả về: JSON chứa danh sách toàn bộ User kèm thông báo thành công.
     */
    public function allUsers()
    {
        try {
            // Lấy toàn bộ danh sách thành viên, sắp xếp theo thời gian đăng ký mới nhất
            $users = User::latest()->get();

            return response()->json([
                'success' => true,
                'data' => $users,
                'message' => 'Tải danh sách thành viên thành công'
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Lỗi hệ thống: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Chức năng: Cập nhật thông tin quyền hạn hoặc trạng thái khóa của một người dùng.
     * Tham số đầu vào: Request $request (role, status), $id (ID của User).
     * Giá trị trả về: JSON xác nhận cập nhật thành công hoặc lỗi nếu vi phạm bảo mật.
     */
    public function updateUser(Request $request, $id) {
        try {
            $user = User::findOrFail($id);

            // Chốt bảo mật: Admin không được phép tự hạ quyền hoặc tự khóa tài khoản của chính mình
            if ($user->id === auth()->id()) {
                return response()->json(['success' => false, 'message' => 'Ông không thể tự xử mình đâu!'], 400);
            }

            // Chỉ cho phép cập nhật nếu các trường gửi lên nằm trong danh sách quy định
            $request->validate([
                'role'   => 'sometimes|in:customer,shop,admin',
                'status' => 'sometimes|in:active,blocked',
            ]);

            $user->update($request->only(['role', 'status']));

            return response()->json([
                'success' => true,
                'message' => 'Cập nhật tài khoản thành công!',
                'data'    => $user
            ]);
        } catch (\Exception $e) {
            return response()->json(['success' => false, 'message' => $e->getMessage()], 500);
        }
    }

}
