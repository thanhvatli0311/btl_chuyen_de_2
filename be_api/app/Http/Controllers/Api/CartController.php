<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Cart;
use App\Models\Phone;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class CartController extends Controller
{
    /**
     * Chức năng: Lấy danh sách toàn bộ sản phẩm trong giỏ hàng của người dùng đang đăng nhập.
     * Tham số đầu vào: Không có.
     * Giá trị trả về: JSON chứa trạng thái và mảng dữ liệu giỏ hàng kèm thông tin máy, shop, thương hiệu.
     */
    public function index()
    {
        // Thực hiện truy vấn nạp chồng (Eager Loading) để lấy thông tin máy, cửa hàng và hãng sản xuất nhằm giảm số lượng câu query SQL
        $cartItems = Cart::with(['phone' => function($q) {
                $q->with(['shop', 'brand']);
            }])
            ->where('user_id', auth()->id())
            ->latest()
            ->get();

        return response()->json([
            'success' => true,
            'data' => $cartItems
        ]);
    }

    /**
     * Chức năng: Thêm một sản phẩm vào giỏ hàng hoặc tăng số lượng nếu sản phẩm đó đã có trong giỏ.
     * Tham số đầu vào: Request $request (chứa phone_id và số lượng quantity).
     * Giá trị trả về: JSON thông báo kết quả và thông tin sản phẩm trong giỏ sau khi xử lý.
     */
    public function store(Request $request)
    {
        // Xác thực dữ liệu: phone_id phải tồn tại trong bảng phones, quantity phải là số nguyên tối thiểu là 1
        $request->validate([
            'phone_id' => 'required|exists:phones,id',
            'quantity' => 'required|integer|min:1',
        ]);

        $phone = Phone::findOrFail($request->phone_id);

        // Kiểm tra xem số lượng khách muốn mua lần đầu có vượt quá số lượng hiện có trong kho không
        if ($phone->stock < $request->quantity) {
            return response()->json([
                'success' => false,
                'message' => 'Số lượng máy trong kho không đủ.'
            ], 400);
        }

        // Tìm kiếm xem trong giỏ hàng của user này đã có sản phẩm này chưa
        $cart = Cart::where('user_id', auth()->id())
                    ->where('phone_id', $request->phone_id)
                    ->first();

        if ($cart) {
            // Logic xử lý khi đã có sản phẩm: Kiểm tra xem (số lượng cũ + số lượng mới) có vượt kho không
            if ($phone->stock < ($cart->quantity + $request->quantity)) {
                return response()->json([
                    'success' => false,
                    'message' => 'Tổng số lượng trong giỏ vượt quá tồn kho.'
                ], 400);
            }
            // Thực hiện tăng số lượng bản ghi hiện có
            $cart->increment('quantity', $request->quantity);
            $cart->refresh();
        } else {
            // Logic xử lý khi chưa có sản phẩm: Tạo bản ghi giỏ hàng mới
            $cart = Cart::create([
                'user_id' => auth()->id(),
                'phone_id' => $request->phone_id,
                'quantity' => $request->quantity
            ]);
        }

        // Nạp lại các quan hệ để trả về đầy đủ dữ liệu cho ứng dụng Flutter hiển thị giao diện
        $cart->load(['phone.shop', 'phone.brand']);

        return response()->json([
            'success' => true,
            'message' => 'Đã thêm vào giỏ hàng.',
            'data' => $cart
        ]);
    }

    /**
     * Chức năng: Cập nhật số lượng của một món hàng cụ thể trong giỏ (Ví dụ: khi khách nhấn nút + hoặc -).
     * Tham số đầu vào: Request $request (số lượng mới), $id (Mã ID của bản ghi giỏ hàng).
     * Giá trị trả về: JSON trạng thái thành công hoặc thông báo lỗi nếu không đủ hàng.
     */
    public function update(Request $request, $id)
    {
        $request->validate(['quantity' => 'required|integer|min:1']);

        // Tìm món hàng trong giỏ của user hiện tại kèm theo dữ liệu máy để kiểm tra kho
        $cart = Cart::with('phone')->where('id', $id)
                    ->where('user_id', auth()->id())
                    ->first();

        if (!$cart) return response()->json(['success' => false, 'message' => 'Không tìm thấy giỏ hàng'], 404);

        // Logic kiểm tra tồn kho: Đảm bảo số lượng cập nhật mới không lớn hơn số lượng máy Shop đang có
        if ($cart->phone->stock < $request->quantity) {
            return response()->json([
                'success' => false,
                'message' => 'Kho chỉ còn ' . $cart->phone->stock . ' sản phẩm.'
            ], 400);
        }

        $cart->update(['quantity' => $request->quantity]);

        return response()->json(['success' => true]);
    }

    /**
     * Chức năng: Gỡ bỏ hoàn toàn một sản phẩm ra khỏi giỏ hàng.
     * Tham số đầu vào: $id (Mã ID của bản ghi giỏ hàng cần xóa).
     * Giá trị trả về: JSON thông báo đã xóa thành công.
     */
    public function destroy($id)
    {
        // Đảm bảo món hàng cần xóa thuộc về đúng người dùng đang đăng nhập
        $cart = Cart::where('id', $id)
            ->where('user_id', auth()->id())
            ->firstOrFail();

        $cart->delete();

        return response()->json([
            'success' => true,
            'message' => 'Đã xóa sản phẩm khỏi giỏ hàng.'
        ]);
    }

    /**
     * Chức năng: Xóa hàng loạt các sản phẩm đã chọn trong giỏ (thường dùng để dọn giỏ sau khi khách đã đặt hàng thành công).
     * Tham số đầu vào: Request $request (chứa mảng cart_ids là danh sách các ID cần xóa).
     * Giá trị trả về: JSON xác nhận số lượng sản phẩm đã được dọn sạch khỏi giỏ.
     */
    public function removeSelected(Request $request)
    {
        // Yêu cầu danh sách ID gửi lên phải là mảng và các ID phải tồn tại trong bảng carts
        $request->validate([
            'cart_ids' => 'required|array',
            'cart_ids.*' => 'integer|exists:carts,id'
        ]);

        // Thực hiện xóa tập trung các bản ghi nằm trong danh sách và thuộc về user này
        $deletedCount = Cart::whereIn('id', $request->cart_ids)
                            ->where('user_id', auth()->id())
                            ->delete();

        return response()->json([
            'success' => true,
            'message' => "Đã xóa $deletedCount sản phẩm đã thanh toán khỏi giỏ hàng."
        ]);
    }
}
