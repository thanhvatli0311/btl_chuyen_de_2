<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\{Complaint, Order, Dispute};
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ComplaintController extends Controller
{
    /**
     * CUSTOMER: Gửi khiếu nại cho một đơn hàng
     */
    public function store(Request $request)
    {
        $request->validate([
            'order_id' => 'required|exists:orders,id',
            'type' => 'required|in:cancel,exchange,return,quality',
            'description' => 'required|string|min:10',
        ]);

        $order = Order::where('id', $request->order_id)
            ->where('customer_id', auth()->id())
            ->firstOrFail();

        // Kiểm tra xem đơn hàng đã có khiếu nại chưa để tránh gửi trùng
        $exists = Complaint::where('order_id', $order->id)->exists();
        if ($exists) {
            return response()->json(['success' => false, 'message' => 'Đơn hàng này đang trong quá trình khiếu nại.'], 400);
        }

        $complaint = Complaint::create([
            'user_id' => auth()->id(),
            'order_id' => $order->id,
            'shop_id' => $order->shop_id, // Lấy shop_id từ đơn hàng
            'type' => $request->type,
            'description' => $request->description,
            'status' => 'pending',
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Khiếu nại của bạn đã được gửi tới hệ thống.',
            'data' => $complaint
        ], 201);
    }

    /**
     * ADMIN: Danh sách khiếu nại toàn sàn
     */
    public function adminIndex()
    {
        $complaints = Complaint::with(['user', 'order', 'shop'])
            ->latest()
            ->paginate(15);

        return response()->json(['success' => true, 'data' => $complaints]);
    }

    /**
     * ADMIN: Phản hồi và Xử lý khiếu nại
     * Nếu giải quyết thỏa đáng, Admin có thể tạo Dispute để lưu phán quyết
     */
    public function resolve(Request $request, $id)
    {
        $request->validate([
            'status' => 'required|in:processing,resolved,rejected',
            'admin_reply' => 'required|string',
            'refund_amount' => 'nullable|numeric|min:0'
        ]);

        return DB::transaction(function () use ($request, $id) {
            $complaint = Complaint::findOrFail($id);
            $complaint->update([
                'status' => $request->status,
                'admin_reply' => $request->admin_reply
            ]);

            // Nếu trạng thái là Resolved (Đã giải quyết) -> Tạo bản ghi Dispute (Tranh chấp)
            if ($request->status === 'resolved') {
                Dispute::updateOrCreate(
                    ['complaint_id' => $complaint->id],
                    [
                        'admin_id' => auth()->id(),
                        'resolution' => $request->admin_reply,
                        'refund_amount' => $request->refund_amount ?? 0,
                        'status' => 'closed'
                    ]
                );
            }

            return response()->json([
                'success' => true,
                'message' => 'Đã cập nhật phương án xử lý khiếu nại.'
            ]);
        });
    }

    /**
     * SHOP: Xem các khiếu nại liên quan đến cửa hàng mình
     */
    public function shopIndex()
    {
        $shopId = auth()->user()->shop->id;

        $complaints = Complaint::with(['user', 'order'])
            ->where('shop_id', $shopId)
            ->latest()
            ->get();

        return response()->json(['success' => true, 'data' => $complaints]);
    }
}
