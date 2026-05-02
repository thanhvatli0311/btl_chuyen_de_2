<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\{Shop, User, Transaction, Order};
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Support\Facades\Log;

class ShopController extends Controller
{
    /**
     * Chức năng: Lấy các số liệu thống kê cơ bản cho màn hình Dashboard của chủ Shop.
     * Tham số đầu vào: Không có (Lấy thông tin qua Auth).
     * Giá trị trả về: JSON chứa tổng doanh thu, tổng đơn hàng, đơn chờ duyệt và số dư ví.
     */
    public function getDashboardStats()
    {
        $shopId = auth()->user()->shop->id;

        $stats = [
            // Tính tổng tiền từ các đơn hàng đã giao thành công
            'total_revenue' => Order::where('shop_id', $shopId)->where('status', 'delivered')->sum('total_amount'),
            // Đếm tổng số lượng đơn hàng không phân biệt trạng thái
            'total_orders' => Order::where('shop_id', $shopId)->count(),
            // Đếm các đơn hàng mới đang ở trạng thái chờ xử lý
            'pending_orders' => Order::where('shop_id', $shopId)->where('status', 'pending')->count(),
            // Lấy số dư khả dụng trong ví tiền của Shop
            'balance' => auth()->user()->shop->balance,
        ];

        return response()->json(['success' => true, 'data' => $stats]);
    }

    /**
     * Chức năng: Hiển thị hồ sơ công khai của Shop dành cho khách hàng xem trên ứng dụng.
     * Tham số đầu vào: $slug (Chuỗi định danh duy nhất của Shop).
     * Giá trị trả về: JSON thông tin chi tiết Shop kèm danh sách 10 sản phẩm đang hoạt động.
     */
    public function publicProfile($slug)
    {
        // Tìm Shop qua slug, nạp kèm danh sách máy đang rao bán và giới hạn số lượng hiển thị
        $shop = Shop::with(['phones' => function($q) {
            $q->where('status', 'active')->limit(10);
        }])->where('slug', $slug)->firstOrFail();

        return response()->json(['success' => true, 'data' => $shop]);
    }

    /**
     * Chức năng: Xuất báo cáo doanh thu và quy mô toàn sàn dành cho quản trị viên (Admin).
     * Tham số đầu vào: Không có.
     * Giá trị trả về: JSON tổng doanh thu hệ thống, tổng số shop, người dùng và các giao dịch gần đây.
     */
    public function adminGlobalReport()
    {
        // Tính tổng giá trị giao dịch của toàn bộ các đơn hàng đã hoàn tất trên hệ thống
        $totalSystemRevenue = Order::where('status', 'delivered')->sum('total_amount');
        $totalShops = Shop::count();
        $totalUsers = User::count();

        return response()->json([
            'success' => true,
            'data' => [
                'system_revenue' => $totalSystemRevenue,
                'total_shops' => $totalShops,
                'total_users' => $totalUsers,
                // Lấy 10 biến động dòng tiền mới nhất để Admin theo dõi
                'recent_transactions' => Transaction::latest()->limit(10)->get()
            ]
        ]);
    }

    /**
     * Chức năng: Cho phép chủ Shop tự khóa cửa hàng tạm thời.
     * Tham số đầu vào: Không có.
     * Giá trị trả về: JSON thông báo trạng thái khóa thành công.
     */
    public function selfLock() {
        $shop = auth()->user()->shop;

        // Cập nhật trạng thái về 'blocked' và lưu vết lý do vào phần mô tả của Shop
        $shop->update([
            'status' => 'blocked',
            'description' => $shop->description . "\n[Hệ thống]: Shop tự đóng cửa ngày " . now()->format('d/m/Y') . ". Yêu cầu mở lại sau 30 ngày."
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Tài khoản đã được khóa tạm thời. Bạn sẽ không bị trừ phí vận hành sàn.'
        ]);
    }

    /**
     * Chức năng: Cập nhật thông tin chi tiết hồ sơ cá nhân của Shop.
     * Tham số đầu vào: Request $request (Chứa thông tin tên, mô tả, ảnh, địa chỉ kho, ngân hàng).
     * Giá trị trả về: JSON dữ liệu Shop sau khi cập nhật.
     */
    public function update(Request $request)
    {
        $shop = auth()->user()->shop;

        // Ràng buộc dữ liệu: Tên shop không được trùng với các shop khác trừ chính nó
        $request->validate([
            'name' => 'sometimes|string|max:255|unique:shops,name,' . $shop->id,
            'description' => 'sometimes|string',
            'avatar' => 'sometimes|string',
            'warehouse_address' => 'sometimes|string',
            'bank_info' => 'sometimes|array',
        ]);

        // Chỉ cập nhật những trường thông tin được gửi lên từ phía Client
        $shop->update($request->only([
            'name', 'description', 'avatar', 'warehouse_address', 'bank_info'
        ]));

        return response()->json([
            'success' => true,
            'message' => 'Cập nhật thành công!',
            'data' => $shop
        ]);
    }

    /**
     * Chức năng: Phân tích tài chính chi tiết, tính toán tăng trưởng và dữ liệu biểu đồ cho Shop.
     * Tham số đầu vào: Request $request (Query start_date, end_date).
     * Giá trị trả về: JSON gồm doanh thu thực nhận, tỷ lệ tăng trưởng và mảng dữ liệu biểu đồ theo ngày.
     */
    public function getRevenueStats(Request $request)
    {
        $shopId = auth()->user()->shop->id;
        $userId = auth()->id();

        // Xác định mốc thời gian xem báo cáo dựa trên yêu cầu của khách hàng
        $startDate = \Carbon\Carbon::parse($request->query('start_date', now()->subDays(7)));
        $endDate = \Carbon\Carbon::parse($request->query('end_date', now()));

        // Tính toán khoảng thời gian tương đương trong quá khứ để so sánh hiệu quả kinh doanh
        $daysDiff = $startDate->diffInDays($endDate) + 1;
        $pastStartDate = $startDate->copy()->subDays($daysDiff);
        $pastEndDate = $startDate->copy()->subSecond();

        // Doanh thu kỳ này: Tổng tiền từ các giao dịch bán hàng, đã trừ đi 5% phí hoa hồng hệ thống
        $currentRevenue = \App\Models\Transaction::where('user_id', $userId)
            ->where('type', 'sale_revenue')
            ->whereBetween('created_at', [$startDate->format('Y-m-d 00:00:00'), $endDate->format('Y-m-d 23:59:59')])
            ->sum('amount') * 0.95;

        // Doanh thu kỳ trước: Dùng để tính toán phần trăm tăng trưởng hoặc sụt giảm
        $pastRevenue = \App\Models\Transaction::where('user_id', $userId)
            ->where('type', 'sale_revenue')
            ->whereBetween('created_at', [$pastStartDate->format('Y-m-d 00:00:00'), $pastEndDate->format('Y-m-d 23:59:59')])
            ->sum('amount') * 0.95;

        // Logic tính % tăng trưởng: Xử lý trường hợp doanh thu kỳ trước bằng 0 để tránh lỗi chia cho 0
        $growthRate = 0;
        if ($pastRevenue > 0) {
            $growthRate = (($currentRevenue - $pastRevenue) / $pastRevenue) * 100;
        } elseif ($currentRevenue > 0) {
            $growthRate = 100;
        }

        // Truy vấn dữ liệu biểu đồ: Nhóm doanh thu thực nhận theo từng ngày trong khoảng thời gian chọn
        $chartData = \App\Models\Transaction::where('user_id', $userId)
            ->where('type', 'sale_revenue')
            ->whereBetween('created_at', [$startDate->format('Y-m-d 00:00:00'), $endDate->format('Y-m-d 23:59:59')])
            ->select([
                DB::raw('DATE(created_at) as date'),
                DB::raw('SUM(amount) * 0.95 as revenue')
            ])
            ->groupBy('date')
            ->orderBy('date', 'ASC')
            ->get();

        return response()->json([
            'success' => true,
            'data' => [
                'total_revenue' => (double) $currentRevenue,
                'balance'       => (double) auth()->user()->shop->balance,
                'total_orders'  => (int) \App\Models\Order::where('shop_id', $shopId)->where('status', 'delivered')->count(),
                'growth_rate'   => (double) round($growthRate, 2),
                'chart_data'    => $chartData
            ]
        ]);
    }

    /**
     * Chức năng: Xử lý đơn đăng ký mở gian hàng mới cho người dùng.
     * Tham số đầu vào: Request $request (Tên Shop, địa chỉ kho).
     * Giá trị trả về: JSON thông tin đơn đăng ký đang ở trạng thái chờ duyệt.
     */
    public function registerShop(Request $request)
    {
        $user = auth()->user();

        // Chặn yêu cầu nếu người dùng này đã có cửa hàng hoặc đang có đơn chờ phê duyệt
        if ($user->shop) {
            return response()->json(['success' => false, 'message' => 'Bạn đã nộp đơn hoặc đã có Shop.'], 400);
        }

        $request->validate([
            'name' => 'required|string|max:255|unique:shops,name',
            'warehouse_address' => 'required|string',
        ]);

        // Tạo bản ghi Shop mới với số dư khởi tạo là 0 và trạng thái mặc định là 'pending'
        $shop = Shop::create([
            'user_id' => $user->id,
            'name' => $request->name,
            // Tạo chuỗi slug tự động từ tên shop kết hợp với timestamp để đảm bảo tính duy nhất của URL
            'slug' => Str::slug($request->name) . '-' . time(),
            'warehouse_address' => $request->warehouse_address,
            'status' => 'pending',
            'balance' => 0,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Đã gửi đơn mở gian hàng, vui lòng đợi Admin phê duyệt.',
            'data' => $shop
        ]);
    }
}
