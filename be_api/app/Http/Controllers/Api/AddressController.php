<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Address;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AddressController extends Controller
{
    /**
     * Chức năng: Lấy danh sách toàn bộ địa chỉ giao hàng của người dùng hiện tại.
     * Tham số đầu vào: Không có.
     * Giá trị trả về: JSON chứa trạng thái thành công và danh sách địa chỉ.
     */
    public function index()
    {
        // Lấy danh sách địa chỉ thuộc quyền sở hữu của user, ưu tiên địa chỉ mặc định hiện lên đầu
        $addresses = auth()->user()->addresses()->orderBy('is_default', 'desc')->get();
        return response()->json(['success' => true, 'data' => $addresses]);
    }

    /**
     * Chức năng: Thêm mới một địa chỉ giao hàng vào tài khoản người dùng.
     * Tham số đầu vào: Request $request (Thông tin địa chỉ người nhận).
     * Giá trị trả về: JSON chứa thông tin địa chỉ vừa tạo và mã trạng thái 201.
     */
    public function store(Request $request)
    {
        // Kiểm tra tính hợp lệ của dữ liệu đầu vào từ người dùng
        $request->validate([
            'recipient_name' => 'required|string',
            'phone' => 'required|string',
            'province' => 'required|string',
            'district' => 'required|string',
            'ward' => 'required|string',
            'detail' => 'required|string',
        ]);

        // Sử dụng Database Transaction để đảm bảo tính toàn vẹn dữ liệu khi thay đổi trạng thái mặc định
        return DB::transaction(function () use ($request) {
            $user = auth()->user();

            // Logic: Nếu là địa chỉ đầu tiên của khách hoặc khách tick chọn làm mặc định
            $isDefault = $user->addresses()->count() == 0 || $request->is_default;

            // Nếu địa chỉ sắp lưu là mặc định, cần đặt toàn bộ địa chỉ cũ của khách về trạng thái không mặc định (0)
            if ($isDefault) {
                $user->addresses()->update(['is_default' => 0]);
            }

            // Tiến hành tạo bản ghi địa chỉ mới gắn với user hiện tại
            $address = $user->addresses()->create(array_merge(
                $request->all(),
                ['is_default' => $isDefault]
            ));

            return response()->json(['success' => true, 'data' => $address], 201);
        });
    }

    /**
     * Chức năng: Cập nhật thông tin chi tiết của một địa chỉ đã có.
     * Tham số đầu vào: Request $request (Dữ liệu thay đổi), $id (Mã định danh địa chỉ).
     * Giá trị trả về: JSON thông báo kết quả cập nhật.
     */
    public function update(Request $request, $id)
    {
        // Tìm địa chỉ trong danh sách của user, nếu không tồn tại sẽ tự động trả về lỗi 404
        $address = auth()->user()->addresses()->findOrFail($id);

        // Xử lý logic thay đổi địa chỉ mặc định: Nếu khách chọn địa chỉ này làm mặc định mới
        if ($request->is_default && !$address->is_default) {
            // Đặt tất cả địa chỉ khác về trạng thái thường trước khi áp dụng cho bản ghi hiện tại
            auth()->user()->addresses()->update(['is_default' => 0]);
        }

        // Cập nhật các trường dữ liệu được gửi lên từ Request
        $address->update($request->all());
        return response()->json(['success' => true, 'message' => 'Cập nhật thành công']);
    }

    /**
     * Chức năng: Xóa một địa chỉ cụ thể khỏi tài khoản.
     * Tham số đầu vào: $id (Mã định danh địa chỉ cần xóa).
     * Giá trị trả về: JSON thông báo kết quả xóa hoặc lỗi nếu vi phạm ràng buộc.
     */
    public function destroy($id)
    {
        // Tìm và xác nhận quyền sở hữu địa chỉ trước khi thực hiện lệnh xóa
        $address = auth()->user()->addresses()->findOrFail($id);

        // Kiểm tra: Không cho phép xóa nếu địa chỉ này đang được đặt làm mặc định để đảm bảo luôn có địa chỉ nhận hàng
        if ($address->is_default) {
            return response()->json(['success' => false, 'message' => 'Không được xóa địa chỉ mặc định'], 400);
        }

        // Thực hiện xóa bản ghi khỏi cơ sở dữ liệu
        $address->delete();
        return response()->json(['success' => true, 'message' => 'Đã xóa địa chỉ']);
    }
}
