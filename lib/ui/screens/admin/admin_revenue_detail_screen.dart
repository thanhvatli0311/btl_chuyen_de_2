import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/base_provider.dart';
import 'admin_shop_detail_screen.dart';

class AdminRevenueDetailScreen extends StatefulWidget {
  const AdminRevenueDetailScreen({super.key});

  @override
  State<AdminRevenueDetailScreen> createState() => _AdminRevenueDetailScreenState();
}

class _AdminRevenueDetailScreenState extends State<AdminRevenueDetailScreen> {
  /// Bộ định dạng tiền tệ Việt Nam dùng chung cho toàn màn hình.
  /// Sử dụng static final để khởi tạo duy nhất một lần, tiết kiệm tài nguyên CPU.
  static final currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  /// Bộ nhớ đệm dùng để lưu trữ các chuỗi ngày tháng đã được xử lý.
  /// Giúp tránh việc phải phân tích cú pháp (parse) ngày tháng liên tục khi người dùng tương tác với biểu đồ.
  static final Map<String, String> _dateCache = {};

  @override
  void initState() {
    super.initState();
    /// Đăng ký hàm nạp dữ liệu ngay sau khi khung hình đầu tiên được hiển thị.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  /// Chức năng: Gọi API để lấy dữ liệu phân tích doanh thu từ server.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void> - Dùng để đồng bộ trạng thái nạp dữ liệu.
  Future<void> _loadData() async {
    final base = context.read<BaseProvider>();
    if (base.token != null) {
      /// Thực hiện gọi hàm fetch từ AdminProvider để cập nhật dữ liệu mới nhất.
      await context.read<AdminProvider>().fetchAdminRevenueAnalytics(base.token!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminProv = context.watch<AdminProvider>();
    final px = context.watch<BaseProvider>().textOffset;
    final isDark = context.watch<BaseProvider>().isDarkMode;
    final theme = Theme.of(context);

    return Scaffold(
      /// Tự động đổi màu nền dựa trên chế độ sáng/tối của hệ thống.
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text("PHÂN TÍCH TOÀN SÀN", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16 + px)),
        actions: [IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh))],
      ),
      body: adminProv.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        /// Tính năng kéo để làm mới danh sách dữ liệu.
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              /// Thanh chọn thời gian lọc dữ liệu.
              _buildDateFilter(context, adminProv, theme, px),
              const SizedBox(height: 20),
              _buildSectionHeader("Biểu đồ doanh thu Shop (GMV)", "Tổng giao dịch toàn sàn", px),

              /// Khu vực hiển thị biểu đồ doanh thu tổng (GMV).
              _buildChart(
                  adminProv.dailyRevenue,
                      (item) => item.totalGmv,
                  Colors.blue,
                  px,
                  theme
              ),
              const SizedBox(height: 30),
              _buildSectionHeader("Biểu đồ hoa hồng sàn (5%)", "Lợi nhuận vận hành thực tế", px),

              /// Khu vực hiển thị biểu đồ hoa hồng sàn thu được.
              _buildChart(
                  adminProv.dailyRevenue,
                      (item) => item.commission,
                  Colors.green,
                  px,
                  theme
              ),

              const SizedBox(height: 30),
              _buildSectionHeader("Xếp hạng & Chi tiết Shop", "Bấm vào shop để xem giao dịch", px),
              const SizedBox(height: 15),

              /// Danh sách thẻ hiển thị các Shop có doanh thu cao nhất.
              ...adminProv.shopRankings.map((shop) => _buildShopDrillDownCard(shop, px, theme)),
            ],
          ),
        ),
      ),
    );
  }

  /// Chức năng: Xây dựng giao diện cho phép chọn khoảng thời gian bắt đầu và kết thúc.
  /// Tham số đầu vào: [context], [prov] (AdminProvider), [theme], [px] (cỡ chữ offset).
  /// Giá trị trả về: Widget chứa thông tin khoảng ngày đang lọc.
  Widget _buildDateFilter(BuildContext context, AdminProvider prov, ThemeData theme, double px) {
    return InkWell(
      onTap: () async {
        /// Hiển thị hộp thoại chọn khoảng ngày mặc định của Flutter.
        final picked = await showDateRangePicker(
          context: context,
          initialDateRange: DateTimeRange(start: prov.startDate, end: prov.endDate),
          firstDate: DateTime(2024),
          lastDate: DateTime.now(),
        );
        /// Nếu người dùng xác nhận chọn ngày, cập nhật lại Provider và tải lại dữ liệu.
        if (picked != null) {
          prov.startDate = picked.start;
          prov.endDate = picked.end;
          _loadData();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.blue, size: 20),
            const SizedBox(width: 15),
            Text(
              "${DateFormat('dd/MM').format(prov.startDate)} - ${DateFormat('dd/MM').format(prov.endDate)}",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px, color: Colors.blue),
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Vẽ biểu đồ đường thể hiện sự biến động của doanh thu theo thời gian.
  /// Tham số đầu vào: [data] (danh sách dữ liệu), [getValue] (hàm lấy giá trị cần vẽ), [color] (màu biểu đồ), [px], [theme].
  /// Giá trị trả về: Widget chứa LineChart.
  Widget _buildChart(List<dynamic> data, double Function(dynamic) getValue, Color color, double px, ThemeData theme) {
    if (data.isEmpty) return const SizedBox(height: 200, child: Center(child: Text("Chưa có dữ liệu...")));

    /// Chuyển đổi dữ liệu thô sang danh sách các điểm ảnh (FlSpot) để biểu đồ có thể hiểu được.
    final List<FlSpot> chartSpots = data.asMap().entries.map((e) => FlSpot(
        e.key.toDouble(),
        getValue(e.value)
    )).toList();

    return Container(
      height: 220,
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
      ),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              tooltipRoundedRadius: 12,
              getTooltipColor: (LineBarSpot touchedSpot) => theme.cardColor.withOpacity(0.9),
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final index = touchedSpot.spotIndex;
                  final model = data[index];
                  final String dateRaw = model.date;

                  /// Kiểm tra ngày đã có trong cache chưa để tăng hiệu năng xử lý chuỗi.
                  if (!_dateCache.containsKey(dateRaw)) {
                    _dateCache[dateRaw] = DateFormat('dd/MM/yyyy').format(DateTime.parse(dateRaw));
                  }

                  /// Hiển thị thông tin ngày và số tiền tương ứng khi chạm vào điểm trên biểu đồ.
                  return LineTooltipItem(
                    "${_dateCache[dateRaw]}\n",
                    TextStyle(color: Colors.grey, fontSize: 10 + px),
                    children: [
                      TextSpan(
                        text: currency.format(getValue(model)),
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13 + px
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
          ),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: chartSpots,
              isCurved: true,
              color: color,
              barWidth: 4,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: color.withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Xây dựng thẻ thông tin tóm tắt doanh thu của một Shop cụ thể.
  /// Tham số đầu vào: [shop] (dữ liệu shop), [px], [theme].
  /// Giá trị trả về: Widget (Card) có khả năng nhấn để chuyển trang.
  Widget _buildShopDrillDownCard(dynamic shop, double px, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)]
      ),
      child: InkWell(
        onTap: () {
          /// Chuyển hướng sang màn hình chi tiết doanh thu của Shop được chọn.
          Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => AdminShopDetailScreen(
                      shopId: shop.id,
                      shopName: shop.name
                  )
              )
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.store, color: Colors.white, size: 20)),
              const SizedBox(width: 15),
              Expanded(
                  child: Text(
                      shop.name ?? 'Shop',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px)
                  )
              ),
              Text(
                  currency.format(shop.revenue ?? 0),
                  style: TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 14 + px)
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  /// Chức năng: Hiển thị tiêu đề chính và tiêu đề phụ cho các phân đoạn dữ liệu.
  /// Tham số đầu vào: [title] (tiêu đề), [sub] (mô tả phụ), [px].
  /// Giá trị trả về: Widget Column chứa các dòng Text.
  Widget _buildSectionHeader(String title, String sub, double px) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15 + px)),
      ),
      Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(sub, style: TextStyle(color: Colors.grey, fontSize: 11 + px)),
      ),
    ],
  );
}