<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use Illuminate\Http\Request;
use Carbon\Carbon;

class NotificationController extends Controller
{
    /**
     * Chức năng: Lấy danh sách thông báo của người dùng hiện tại (Phân trang).
     * Tham số đầu vào: Request $request (Lấy user qua Sanctum Token [cite: 393]).
     * Giá trị trả về: JSON chứa danh sách thông báo sắp xếp mới nhất lên đầu.
     */
    public function index(Request $request)
    {
        // Lấy ID của người dùng đang đăng nhập từ hệ thống [cite: 393]
        $userId = auth()->id();

        // Truy vấn danh sách thông báo, phân trang 15 bản ghi để Flutter load mượt
        $notifications = Notification::where('user_id', $userId)
            ->latest()
            ->paginate(15);

        return response()->json([
            'success' => true,
            'data' => $notifications
        ]);
    }

    /**
     * Chức năng: Đánh dấu một thông báo cụ thể là đã đọc.
     * Tham số đầu vào: $id (ID của thông báo).
     * Giá trị trả về: JSON xác nhận cập nhật thành công.
     */
    public function markAsRead($id)
    {
        // Tìm thông báo thuộc về chính user đó để đảm bảo bảo mật
        $notification = Notification::where('id', $id)
            ->where('user_id', auth()->id())
            ->firstOrFail();

        // Cập nhật trạng thái và thời gian đọc thực tế
        $notification->update([
            'is_read' => true,
            'read_at' => Carbon::now()
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Đã đánh dấu đọc thông báo.'
        ]);
    }

    /**
     * Chức năng: Đánh dấu TẤT CẢ thông báo của user là đã đọc.
     * Tham số đầu vào: Không có.
     * Giá trị trả về: JSON thông báo số lượng bản ghi đã xử lý.
     */
    public function markAllAsRead()
    {
        $userId = auth()->id();

        // Tìm tất cả các thông báo chưa đọc của user này
        $count = Notification::where('user_id', $userId)
            ->where('is_read', false)
            ->update([
                'is_read' => true,
                'read_at' => Carbon::now()
            ]);

        return response()->json([
            'success' => true,
            'message' => "Đã xử lý đọc cho $count thông báo."
        ]);
    }

    /**
     * Chức năng: Xóa một thông báo.
     * Tham số đầu vào: $id (ID thông báo cần xóa).
     * Giá trị trả về: JSON xác nhận xóa thành công.
     */
    public function destroy($id)
    {
        // Kiểm tra quyền sở hữu trước khi thực hiện xóa bản ghi
        $notification = Notification::where('id', $id)
            ->where('user_id', auth()->id())
            ->firstOrFail();

        $notification->delete();

        return response()->json([
            'success' => true,
            'message' => 'Đã xóa thông báo khỏi hệ thống.'
        ]);
    }
}
