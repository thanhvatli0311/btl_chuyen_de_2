<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\{Transaction, Shop, User, SystemSetting, Order};
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class TransactionController extends Controller
{
    /**
     * Chức năng: Truy vấn toàn bộ lịch sử biến động số dư của người dùng đang đăng nhập.
     * Tham số đầu vào: Không có.
     * Giá trị trả về: JSON chứa danh sách các giao dịch từ mới đến cũ.
     */
    public function index()
    {
        // Lấy danh sách giao dịch dựa trên ID người dùng, ưu tiên bản ghi mới nhất
        $transactions = Transaction::where('user_id', auth()->id())
            ->latest()
            ->get();

        return response()->json([
            'success' => true,
            'data' => $transactions
        ]);
    }

    /**
     * Chức năng: Kiểm tra trạng thái ví tiền của chủ Shop và các quy định về tiền cọc vận hành.
     * Tham số đầu vào: Không có.
     * Giá trị trả về: JSON thông tin số dư thực tế và mức tiền cọc tối thiểu bắt buộc.
     */
    public function shopWallet()
    {
        $shop = auth()->user()->shop;

        // Chốt bảo mật: Chỉ những tài khoản đã đăng ký Shop mới được phép xem ví này
        if (!$shop) {
            return response()->json(['success' => false, 'message' => 'Bạn không có quyền truy cập ví shop.'], 403);
        }

        // Truy xuất cấu hình tiền cọc tối thiểu từ Database (mặc định 1.000.000đ nếu chưa thiết lập)
        $minRequired = SystemSetting::where('key_name', 'min_deposit')->first()->value ?? 1000000;

        return response()->json([
            'success' => true,
            'balance' => $shop->balance,
            'shop_name' => $shop->name,
            'min_required' => (int) $minRequired
        ]);
    }

    /**
     * Chức năng: Tiếp nhận và xử lý yêu cầu rút tiền từ ví Shop về tài khoản ngân hàng.
     * Tham số đầu vào: Request $request (số tiền muốn rút 'amount', thông tin ngân hàng 'bank_info').
     * Giá trị trả về: JSON thông báo trạng thái yêu cầu hoặc lỗi ràng buộc số dư.
     */
    public function withdraw(Request $request)
    {
        $request->validate([
            'amount' => 'required|numeric|min:50000',
            'bank_info' => 'required|string',
        ]);

        $shop = auth()->user()->shop;

        // Kiểm tra điều kiện: Shop phải ở trạng thái đã được duyệt mới được phép thực hiện rút tiền
        if (!$shop || $shop->status !== 'approved') {
            return response()->json(['success' => false, 'message' => 'Tài khoản shop chưa được duyệt hoặc đang bị khóa.'], 403);
        }

        // Kiểm tra ràng buộc số dư duy trì: Không cho phép rút lấn vào số tiền cọc vận hành
        $minBalance = SystemSetting::where('key_name', 'min_deposit')->first()->value ?? 1000000;

        if (($shop->balance - $request->amount) < $minBalance) {
            return response()->json([
                'success' => false,
                'message' => "Bạn phải duy trì số dư tối thiểu " . number_format($minBalance) . "đ làm tiền cọc vận hành."
            ], 400);
        }

        return DB::transaction(function () use ($shop, $request) {
            // Sử dụng lockForUpdate để khóa bản ghi Shop, tránh tranh chấp dữ liệu khi có nhiều yêu cầu cùng lúc
            $shopRefresh = Shop::lockForUpdate()->find($shop->id);

            // Trừ tiền trực tiếp vào ví của Shop
            $shopRefresh->decrement('balance', $request->amount);

            // Khởi tạo bản ghi giao dịch loại 'withdraw' (Rút tiền)
            $transaction = Transaction::create([
                'user_id' => auth()->id(),
                'type' => 'withdraw',
                'amount' => $request->amount,
                'balance_after' => $shopRefresh->balance,
                'reference_id' => null, // Sẽ được cập nhật sau khi Admin chuyển khoản thật
                'content' => 'Rút tiền về: ' . $request->bank_info
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Yêu cầu rút tiền thành công. Vui lòng chờ Admin xử lý.',
                'data' => $transaction
            ]);
        });
    }

    /**
     * Chức năng: Công cụ dành cho Quản trị viên để thực hiện thu phí quản lý sàn định kỳ từ các Shop.
     * Tham số đầu vào: Không có.
     * Giá trị trả về: JSON báo cáo số lượng các Shop đã thực hiện thu phí thành công.
     */
    public function collectFees()
    {
        // Lấy định mức phí cố định từ cấu hình hệ thống
        $feeAmount = SystemSetting::where('key_name', 'min_deposit')->first()->value ?? 1000000;

        $shops = Shop::where('status', 'approved')->get();
        $count = 0;

        foreach ($shops as $shop) {
            DB::transaction(function () use ($shop, $feeAmount, &$count) {
                // Đảm bảo tính toán chính xác số dư tại thời điểm thu phí
                $shopRefresh = Shop::lockForUpdate()->find($shop->id);
                $shopRefresh->decrement('balance', $feeAmount);

                // Ghi nhận lịch sử thu phí hệ thống
                Transaction::create([
                    'user_id' => $shopRefresh->user_id,
                    'type' => 'withdraw',
                    'amount' => $feeAmount,
                    'balance_after' => $shopRefresh->balance,
                    'reference_id' => 'FEE-' . now()->format('mY'),
                ]);

                // Xử lý nợ phí: Nếu ví bị âm tiền, tự động hạ trạng thái để yêu cầu Shop nạp thêm tiền cọc
                if ($shopRefresh->balance < 0) {
                    $shopRefresh->update(['status' => 'pending']);
                }
                $count++;
            });
        }

        return response()->json(['success' => true, 'message' => "Đã thu phí thành công cho $count shop."]);
    }

    /**
     * Chức năng: Thống kê doanh thu thực nhận (sau phí) và phân tích tăng trưởng phục vụ báo cáo tài chính.
     * Tham số đầu vào: Request $request (start_date, end_date để lọc khoảng thời gian).
     * Giá trị trả về: JSON gồm số dư, tổng doanh thu, tỷ lệ tăng trưởng và dữ liệu biểu đồ.
     */
    public function getRevenueStats(Request $request)
    {
        $shopId = auth()->user()->shop->id;
        $userId = auth()->id();

        // Thiết lập khoảng thời gian xem báo cáo (mặc định là từ đầu tháng đến hiện tại)
        $start = $request->query('start_date', now()->startOfMonth()->format('Y-m-d'));
        $end = $request->query('end_date', now()->format('Y-m-d'));

        // Lấy tỷ lệ phí sàn (ví dụ 5%) từ bảng cấu hình để tính tiền thực nhận (GMV Net)
        $platformFeePercent = SystemSetting::where('key_name', 'platform_fee')->first()->value ?? 5;
        $multiplier = (100 - $platformFeePercent) / 100;

        // Doanh thu thực tế: Tổng tiền đơn hàng thành công nhân với hệ số thực nhận (95%)
        $currentRevenue = Order::where('shop_id', $shopId)
            ->where('status', 'delivered')
            ->whereBetween('created_at', [$start . ' 00:00:00', $end . ' 23:59:59'])
            ->sum('total_amount') * $multiplier;

        // Doanh thu tháng cũ: Dùng làm căn cứ để tính toán mức độ tăng trưởng kinh doanh
        $pastRevenue = Order::where('shop_id', $shopId)
            ->where('status', 'delivered')
            ->whereMonth('created_at', now()->subMonth()->month)
            ->sum('total_amount') * $multiplier;

        $growth = 0;
        if ($pastRevenue > 0) {
            $growth = (($currentRevenue - $pastRevenue) / $pastRevenue) * 100;
        }

        return response()->json([
            'success' => true,
            'data' => [
                'balance' => (double) auth()->user()->shop->balance,
                'total_revenue' => (double) $currentRevenue,
                'growth_rate' => round($growth, 2),
                'total_orders' => Order::where('shop_id', $shopId)->where('status', 'delivered')->count(),
                'chart_data' => $this->getChartData($userId, $start, $end, $multiplier)
            ]
        ]);
    }

    /**
     * Chức năng: Hàm hỗ trợ bóc tách và nhóm doanh thu theo từng ngày để phục vụ hiển thị biểu đồ FlChart trên Flutter.
     * Tham số đầu vào: $userId, $start, $end, $multiplier (tỷ lệ thực nhận).
     * Giá trị trả về: Collection dữ liệu gồm các mốc ngày và số tiền tương ứng.
     */
    private function getChartData($userId, $start, $end, $multiplier)
    {
        // Truy vấn bảng giao dịch, lọc theo loại 'sale_revenue' và nhóm theo ngày
        return Transaction::where('user_id', $userId)
            ->where('type', 'sale_revenue')
            ->whereBetween('created_at', [$start . ' 00:00:00', $end . ' 23:59:59'])
            ->select([
                DB::raw('DATE(created_at) as date'),
                DB::raw("SUM(amount) * $multiplier as revenue")
            ])
            ->groupBy('date')
            ->get();
    }
}
