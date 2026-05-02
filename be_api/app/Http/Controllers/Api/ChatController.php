<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Chat;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use App\Models\User;

class ChatController extends Controller
{
    /**
     * Chức năng: Lấy toàn bộ lịch sử tin nhắn giữa người dùng hiện tại và một người dùng cụ thể.
     * Tham số đầu vào: $receiverId (Mã định danh của người nhận tin).
     * Giá trị trả về: JSON chứa danh sách các tin nhắn đã được sắp xếp theo thời gian.
     */
    public function getMessages($receiverId)
    {
        $myId = auth()->id();

        // Truy vấn các tin nhắn mà mình gửi cho họ HOẶC họ gửi cho mình
        $messages = Chat::where(function($q) use ($myId, $receiverId) {
            $q->where('from_user_id', $myId)->where('to_user_id', $receiverId);
        })->orWhere(function($q) use ($myId, $receiverId) {
            $q->where('from_user_id', $receiverId)->where('to_user_id', $myId);
        })
        ->orderBy('created_at', 'asc') // Sắp xếp theo thứ tự thời gian tăng dần để hiển thị đúng luồng chat
        ->get();

        // Tự động cập nhật trạng thái đã xem cho tất cả tin nhắn đối phương gửi cho mình khi mình mở hộp thoại
        Chat::where('from_user_id', $receiverId)
            ->where('to_user_id', $myId)
            ->where('is_read', false)
            ->update(['is_read' => true]);

        return response()->json(['success' => true, 'data' => $messages]);
    }

    /**
     * Chức năng: Lưu tin nhắn mới vào cơ sở dữ liệu và tạo thông báo cho người nhận.
     * Tham số đầu vào: Request $request (Chứa to_user_id và nội dung message).
     * Giá trị trả về: JSON thông tin tin nhắn vừa tạo và mã trạng thái 201.
     */
    public function sendMessage(Request $request)
    {
        // Kiểm tra dữ liệu đầu vào: Người nhận phải tồn tại và tin nhắn không được để trống
        $request->validate([
            'to_user_id' => 'required|exists:users,id',
            'message' => 'required|string'
        ]);

        // Khởi tạo bản ghi tin nhắn mới trong bảng chats
        $chat = Chat::create([
            'from_user_id' => auth()->id(),
            'to_user_id' => $request->to_user_id,
            'message' => $request->message,
            'is_read' => false
        ]);

        // Đồng thời tạo một bản ghi thông báo để người nhận biết có tin nhắn mới (hiển thị trên App Flutter)
        \App\Models\Notification::create([
                'user_id' => $request->to_user_id,
                'title'   => 'Bạn có tin nhắn mới 💬',
                'content' => 'Có người vừa nhắn tin cho bạn, hãy vào kiểm tra ngay nhé!',
                'is_read' => false
            ]);

        return response()->json(['success' => true, 'data' => $chat], 201);
    }

    /**
     * Chức năng: Lấy danh sách tất cả các cuộc hội thoại mà người dùng hiện tại đã tham gia.
     * Tham số đầu vào: Không có.
     * Giá trị trả về: JSON danh sách các hội thoại kèm thông tin đối phương, tin nhắn cuối cùng và số tin chưa đọc.
     */
    public function getChatList()
    {
        $authId = auth()->id();

        // Bước 1: Thu thập toàn bộ ID của những người dùng đã từng tương tác tin nhắn với mình
        $userIds = Chat::where('from_user_id', $authId)->pluck('to_user_id')
            ->merge(Chat::where('to_user_id', $authId)->pluck('from_user_id'))
            ->unique() // Loại bỏ các ID trùng lặp
            ->filter(fn($id) => $id != $authId); // Loại bỏ chính mình ra khỏi danh sách

        // Bước 2: Duyệt qua danh sách ID để tổng hợp dữ liệu cho từng cuộc hội thoại
        $conversations = User::whereIn('id', $userIds)->get()->map(function($user) use ($authId) {
            // Tìm nội dung tin nhắn mới nhất giữa hai người để hiển thị bản tin vắn
            $lastMessage = Chat::where(function($q) use ($authId, $user) {
                $q->where('from_user_id', $authId)->where('to_user_id', $user->id);
            })->orWhere(function($q) use ($authId, $user) {
                $q->where('from_user_id', $user->id)->where('to_user_id', $authId);
            })->latest()->first();

            // Đếm số lượng tin nhắn mà đối phương gửi nhưng mình chưa bấm vào xem
            $unreadCount = Chat::where('from_user_id', $user->id)
                ->where('to_user_id', $authId)
                ->where('is_read', false)
                ->count();

            // Trả về cấu trúc dữ liệu chuẩn để đồng bộ hóa với ConversationModel trên ứng dụng di động
            return [
                'id' => $user->id,
                'other_user' => $user,
                'last_message' => $lastMessage,
                'unread_count' => $unreadCount
            ];
        });

        return response()->json(['success' => true, 'data' => $conversations]);
    }

    /**
     * Chức năng: Đánh dấu thủ công toàn bộ tin nhắn từ một người gửi cụ thể là đã đọc.
     * Tham số đầu vào: $receiverId (ID của người gửi mà mình muốn đánh dấu đã xem).
     * Giá trị trả về: JSON thông báo kết quả thành công hoặc lỗi dữ liệu.
     */
    public function markAsRead($receiverId)
    {
        // Kiểm tra tính hợp lệ của ID người gửi
        if ($receiverId <= 0) return response()->json(['success' => false], 400);

        // Cập nhật trường is_read thành true cho các tin nhắn chưa đọc mà đối phương gửi tới mình
        Chat::where('from_user_id', $receiverId)
            ->where('to_user_id', auth()->id())
            ->where('is_read', false)
            ->update(['is_read' => true]);

        return response()->json(['success' => true]);
  }

}
