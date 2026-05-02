<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Review;
use App\Models\Phone;
use App\Models\Order;
use Illuminate\Http\Request;

class ReviewController extends Controller
{
    /**
     * Chức năng: Lấy danh sách toàn bộ đánh giá của một sản phẩm điện thoại cụ thể.
     * Tham số đầu vào: $phoneId (Mã định danh của điện thoại).
     * Giá trị trả về: JSON chứa trạng thái thành công và mảng dữ liệu các bài đánh giá.
     */
    public function index($phoneId) {
        // Truy vấn bảng reviews kèm theo thông tin người dùng (user) đã viết đánh giá đó
        // Sắp xếp theo thứ tự đánh giá mới nhất hiện lên trên cùng
        $reviews = Review::with('user')->where('phone_id', $phoneId)->latest()->get();
        return response()->json(['success' => true, 'data' => $reviews]);
    }

    /**
     * Chức năng: Tiếp nhận và lưu trữ nội dung đánh giá sản phẩm từ khách hàng.
     * Tham số đầu vào: Request $request (Chứa phone_id, số sao rating và nội dung comment).
     * Giá trị trả về: JSON thông báo kết quả thực hiện hoặc lỗi quyền truy cập.
     */
    public function store(Request $request) {
        // Kiểm tra tính hợp lệ của dữ liệu: Rating bắt buộc từ 1 đến 5 sao, bình luận tối đa 500 ký tự
        $request->validate([
            'phone_id' => 'required|exists:phones,id',
            'rating'   => 'required|integer|min:1|max:5',
            'comment'  => 'nullable|string|max:500',
        ]);

        $userId = auth()->id();

        // Bước kiểm tra quan trọng: Xác minh xem người dùng hiện tại đã thực sự mua và nhận máy này chưa?
        // Chỉ cho phép đánh giá khi đơn hàng có trạng thái là 'delivered' (đã giao hàng thành công)
        $hasBought = Order::where('customer_id', $userId)
            ->where('status', 'delivered')
            ->whereHas('items', function($q) use ($request) {
                $q->where('phone_id', $request->phone_id);
            })->exists();

        // Nếu khách chưa mua hoặc đơn hàng chưa hoàn tất, từ chối quyền đánh giá (Lỗi 403 Forbidden)
        if (!$hasBought) {
            return response()->json(['success' => false, 'message' => 'Bạn cần mua sản phẩm này để đánh giá.'], 403);
        }

        // Thực hiện logic lưu trữ: Nếu người dùng đã đánh giá máy này rồi thì cập nhật nội dung cũ,
        // nếu chưa có thì tạo mới bản ghi (ngăn chặn tình trạng 1 người đăng nhiều đánh giá rác cho 1 máy).
        $review = Review::updateOrCreate(
            ['user_id' => $userId, 'phone_id' => $request->phone_id],
            ['rating' => $request->rating, 'comment' => $request->comment]
        );

        return response()->json(['success' => true, 'message' => 'Cảm ơn bạn đã đánh giá!', 'data' => $review]);
    }
}
