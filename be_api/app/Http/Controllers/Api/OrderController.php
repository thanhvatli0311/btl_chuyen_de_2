<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;

use App\Models\{Order, OrderItem, Phone, OrderStatusLog, Transaction, Shop, Address, Cart};
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class OrderController extends Controller
{
    /**
     * Chức năng: Xử lý quy trình đặt hàng từ giỏ hàng cho khách hàng.
     * Tham số đầu vào: Request $request (Thông tin người nhận, phương thức thanh toán, danh sách ID giỏ hàng).
     * Giá trị trả về: JSON thông báo kết quả đặt hàng.
     */
    public function checkout(Request $request)
    {
        $request->validate([
            'payment_method' => 'required|in:cod,bank_transfer,e-wallet',
            'name' => 'required',
            'phone' => 'required',
            'address' => 'required',
            'province' => 'required',
            'district' => 'required',
            'ward' => 'required',
            'cart_ids' => 'required|array',
        ]);

        return DB::transaction(function () use ($request) {
            $user = auth()->user();

            // Lấy danh sách sản phẩm trong giỏ dựa trên các ID được chọn từ Flutter gửi lên
            $cartItems = Cart::whereIn('id', $request->cart_ids)
                ->where('user_id', $user->id)
                ->with('phone')
                ->get();

            if ($cartItems->isEmpty()) {
                return response()->json(['success' => false, 'message' => 'Giỏ hàng trống hoặc món hàng không tồn tại.'], 400);
            }

            // Đồng bộ thông tin địa chỉ: Nếu khách đã có địa chỉ mặc định thì cập nhật, chưa có thì tạo mới
            $address = Address::updateOrCreate(
                ['user_id' => $user->id, 'is_default' => 1],
                [
                    'recipient_name' => $request->name,
                    'phone' => $request->phone,
                    'province' => $request->province,
                    'district' => $request->district,
                    'ward' => $request->ward,
                    'detail' => $request->address,
                ]
            );

            // Gom nhóm các sản phẩm theo ID của Shop để tách thành nhiều đơn hàng riêng biệt nếu khách mua từ nhiều shop
            $groupedItems = $cartItems->groupBy(fn($item) => $item->phone->shop_id);

            foreach ($groupedItems as $shopId => $items) {
                $subTotal = 0;
                foreach ($items as $item) {
                    // Kiểm tra tồn kho thực tế trước khi chốt đơn
                    if ($item->phone->stock < $item->quantity) {
                        throw new \Exception("Sản phẩm '{$item->phone->title}' đã hết hàng.");
                    }

                    // Tính toán tổng tiền dựa trên giá khuyến mãi hoặc giá gốc
                    $price = $item->phone->discount_price ?? $item->phone->price;
                    $subTotal += ($price * $item->quantity);

                    // Thực hiện trừ số lượng trong kho ngay khi đặt hàng
                    $item->phone->decrement('stock', $item->quantity);
                }

                // Khởi tạo bản ghi đơn hàng tổng
                $order = Order::create([
                    'code' => 'ORD-' . strtoupper(Str::random(10)),
                    'customer_id' => $user->id,
                    'shop_id' => $shopId,
                    'address_id' => $address->id,
                    'total_amount' => $subTotal,
                    'status' => 'pending',
                    'payment_method' => $request->payment_method,
                    'is_paid' => 0,
                ]);

                // Lưu chi tiết từng sản phẩm vào bảng order_items
                foreach ($items as $item) {
                    $order->items()->create([
                        'phone_id' => $item->phone_id,
                        'quantity' => $item->quantity,
                        'price' => $item->phone->discount_price ?? $item->phone->price,
                    ]);
                }
            }

            // Dọn dẹp giỏ hàng: Xóa các món đã đặt thành công để tránh mua lặp lại
            Cart::whereIn('id', $request->cart_ids)->where('user_id', $user->id)->delete();

            return response()->json(['success' => true, 'message' => 'Đặt hàng thành công!'], 201);
        });
    }

    /**
     * Chức năng: Cập nhật trạng thái đơn hàng và xử lý dòng tiền (áp dụng cho Shop).
     * Tham số đầu vào: Request $request (status mới), $id (ID đơn hàng).
     * Giá trị trả về: JSON kết quả cập nhật.
     */
    public function updateStatus(Request $request, $id)
    {
        $request->validate(['status' => 'required|in:pending,confirmed,shipping,delivered,cancelled']);

        return DB::transaction(function () use ($request, $id) {
            // Xác thực đơn hàng thuộc quyền quản lý của Shop đang đăng nhập
            $order = Order::where('id', $id)
                ->where('shop_id', auth()->user()->shop->id)
                ->with(['items', 'shop'])
                ->firstOrFail();

            $oldStatus = $order->status;
            $newStatus = $request->status;

            if ($oldStatus === $newStatus) return response()->json(['success' => true, 'message' => 'Trạng thái không đổi.']);

            // Trường hợp 1: Nếu đơn hàng bị hủy, thực hiện hoàn trả số lượng vào kho máy
            if ($newStatus === 'cancelled' && $oldStatus !== 'cancelled') {
                foreach ($order->items as $item) {
                    Phone::where('id', $item->phone_id)->increment('stock', $item->quantity);
                }
            }

            // Trường hợp 2: Khi đơn hàng hoàn tất, tính phí sàn 5% và cộng tiền vào ví cho Shop
            if ($newStatus === 'delivered' && !$order->is_paid) {
                $total = $order->total_amount;
                $fee = $total * 0.05;
                $revenue = $total - $fee;

                $shop = $order->shop;
                $shop->increment('balance', $revenue);

                Transaction::create([
                    'user_id' => $shop->user_id,
                    'type' => 'sale_revenue',
                    'amount' => $revenue,
                    'balance_after' => $shop->balance,
                    'reference_id' => $order->code
                ]);

                $order->is_paid = true;
            }

            // Thực hiện cập nhật trạng thái mới
            $order->status = $newStatus;
            $order->save();

            // Định nghĩa nội dung thông báo tiếng Việt theo từng trạng thái
            $notiMessages = [
                'confirmed' => [
                    'title' => '📩 Đơn hàng đã được xác nhận',
                    'content' => ' Đơn hàng của bạn đang được xử lý, xin hãy chờ đợi.'
                ],
                'shipping' => [
                    'title' => '🛫 Đang giao hàng',
                    'content' => '  Đơn hàng của bạn đang trên đường giao, hãy chú ý cuộc gọi của shipper.'
                ],
                'delivered' => [
                    'title' => ' 🏁 Giao hàng thành công',
                    'content' => 'Đơn hàng của bạn đã được giao thành công. Cảm ơn bạn đã tin tưởng TSP Market!'
                ],
                'cancelled' => [
                    'title' => '📵 Đơn hàng đã bị hủy',
                    'content' => 'Đơn hàng của bạn đã bị hủy. Vui lòng kiểm tra lại lý do hoặc liên hệ với Shop.'
                ],
            ];

            // Chỉ tạo thông báo nếu trạng thái mới nằm trong danh sách cần báo tin
            if (isset($notiMessages[$newStatus])) {
                \App\Models\Notification::create([
                    'user_id' => $order->customer_id,
                    'title'   => $notiMessages[$newStatus]['title'],
                    'content' => $notiMessages[$newStatus]['content'],
                    'type'    => 'order_update',
                    'is_read' => false,
                ]);
            }
            // ---------------------------------------------------------

            // Lưu nhật ký thay đổi trạng thái để truy vết
            OrderStatusLog::create([
                'order_id' => $order->id,
                'status_from' => $oldStatus,
                'status_to' => $newStatus,
                'reason' => $request->reason ?? 'Cập nhật bởi cửa hàng.',
                'changed_by' => auth()->id()
            ]);

            return response()->json(['success' => true, 'message' => "Đã chuyển đơn hàng sang: $newStatus"]);
        });
    }

    /**
     * Chức năng: Lấy danh sách đơn hàng đã mua của khách hàng hiện tại.
     * Tham số đầu vào: Request $request (có thể lọc theo query 'status').
     * Giá trị trả về: JSON danh sách đơn hàng kèm đầy đủ thông tin máy, shop và địa chỉ.
     */
    public function customerOrders(Request $request)
    {
        $status = $request->query('status');
        $query = Order::with(['items.phone', 'shop', 'address'])
                      ->where('customer_id', auth()->id())
                      ->latest();

        // Nếu có tham số status (khác 'all'), thực hiện lọc theo trạng thái yêu cầu
        if ($status && $status !== 'all') {
            $query->where('status', $status);
        }

        return response()->json(['success' => true, 'data' => $query->get()]);
    }

    /**
     * Chức năng: Cho phép khách hàng chủ động hủy đơn hàng khi vẫn đang ở trạng thái chờ duyệt.
     * Tham số đầu vào: Request $request (lý do hủy), $id (ID đơn hàng).
     * Giá trị trả về: JSON kết quả hủy đơn.
     */
    public function cancel(Request $request, $id)
    {
        return DB::transaction(function () use ($request, $id) {
            // Đơn hàng chỉ được phép hủy bởi chính chủ và khi Shop chưa duyệt (pending)
            $order = Order::where('id', $id)
                ->where('customer_id', auth()->id())
                ->where('status', 'pending')
                ->with('items.phone')
                ->first();

            if (!$order) return response()->json(['success' => false, 'message' => 'Không thể hủy đơn hàng này.'], 400);

            // Hoàn lại số lượng máy vào kho cho Shop sau khi khách hủy
            foreach ($order->items as $item) {
                if ($item->phone) $item->phone->increment('stock', $item->quantity);
            }

            $order->update(['status' => 'cancelled']);

            // Ghi log lý do khách hàng chủ động hủy
            OrderStatusLog::create([
                'order_id' => $order->id,
                'status_from' => 'pending',
                'status_to' => 'cancelled',
                'reason' => $request->reason ?? 'Khách hàng chủ động hủy.',
                'changed_by' => auth()->id()
            ]);

            return response()->json(['success' => true, 'message' => 'Đã hủy đơn và hoàn kho!']);
        });
    }

    /**
     * Chức năng: Lấy toàn bộ danh sách đơn hàng đổ về Shop của người dùng hiện tại.
     * Tham số đầu vào: Không có.
     * Giá trị trả về: JSON mảng các đơn hàng kèm thông tin chi tiết máy và địa chỉ giao hàng.
     */
    public function shopOrders() {
        $shop = auth()->user()->shop;
        if (!$shop) return response()->json(['success' => true, 'data' => []]);

        $orders = Order::with(['items.phone', 'address'])
            ->where('shop_id', $shop->id)
            ->latest()
            ->get();

        return response()->json(['success' => true, 'data' => $orders]);
    }
}
