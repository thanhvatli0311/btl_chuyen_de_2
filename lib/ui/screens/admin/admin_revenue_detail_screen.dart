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
  // Bộ định dạng tiền tệ VNĐ dùng chung cho toàn bộ màn hình
  static final currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  // Cache lưu trữ chuỗi ngày đã format để tránh format lại nhiều lần (tối ưu hiệu năng)
  static final Map<String, String> _dateCache = {};

  @override
  void initState() {
    super.initState();
    // Sau khi UI render xong frame đầu tiên thì gọi API lấy dữ liệu
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  // Hàm lấy dữ liệu doanh thu từ server thông qua AdminProvider
  // Input: không có
  // Output: Future<void>
  Future<void> _loadData() async {
    final base = context.read<BaseProvider>();
    // Kiểm tra token tồn tại trước khi gọi API
    if (base.token != null) {
      await context.read<AdminProvider>().fetchAdminRevenueAnalytics(base.token!);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lắng nghe dữ liệu từ provider để tự động rebuild UI khi có thay đổi
    final adminProv = context.watch<AdminProvider>();
    final px = context.watch<BaseProvider>().textOffset;
    final isDark = context.watch<BaseProvider>().isDarkMode;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text("PHÂN TÍCH TOÀN SÀN", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16 + px)),
        actions: [
          // Nút refresh để tải lại dữ liệu
          IconButton(onPressed: _loadData, icon: const Icon(Icons.refresh))
        ],
      ),
      body: adminProv.isLoading
      // Hiển thị loading khi đang gọi API
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        // Kéo xuống để refresh dữ liệu
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Bộ lọc chọn khoảng thời gian
              _buildDateFilter(context, adminProv, theme, px),
              const SizedBox(height: 20),

              // Tiêu đề biểu đồ GMV
              _buildSectionHeader("Biểu đồ doanh thu Shop (GMV)", "Tổng giao dịch toàn sàn", px),

              // Biểu đồ GMV (màu xanh dương)
              _buildChart(adminProv.dailyRevenue, (item) => item.totalGmv, Colors.blue, px, theme),

              const SizedBox(height: 30),

              // Tiêu đề biểu đồ hoa hồng
              _buildSectionHeader("Biểu đồ hoa hồng sàn (5%)", "Lợi nhuận vận hành thực tế", px),

              // Biểu đồ hoa hồng (màu xanh lá)
              _buildChart(adminProv.dailyRevenue, (item) => item.commission, Colors.green, px, theme),

              const SizedBox(height: 30),

              // Tiêu đề danh sách shop
              _buildSectionHeader("Xếp hạng & Chi tiết Shop", "Bấm vào shop để xem giao dịch", px),
              const SizedBox(height: 15),

              // Render danh sách shop theo ranking
              ...adminProv.shopRankings.map((shop) => _buildShopDrillDownCard(shop, px, theme)),
            ],
          ),
        ),
      ),
    );
  }

  // Widget tạo bộ lọc chọn khoảng ngày
  // Input: context, provider, theme, px
  // Output: Widget
  Widget _buildDateFilter(BuildContext context, AdminProvider prov, ThemeData theme, double px) {
    return InkWell(
      onTap: () async {
        // Mở dialog chọn khoảng ngày
        final picked = await showDateRangePicker(
          context: context,
          initialDateRange: DateTimeRange(start: prov.startDate, end: prov.endDate),
          firstDate: DateTime(2024),
          lastDate: DateTime.now(),
        );

        // Nếu người dùng chọn ngày thì cập nhật lại provider và reload dữ liệu
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
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Colors.blue, size: 20),
            const SizedBox(width: 15),

            // Hiển thị khoảng ngày đã chọn
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

  // Widget vẽ biểu đồ đường từ dữ liệu truyền vào
  // Input:
  // - data: danh sách dữ liệu
  // - getValue: hàm lấy giá trị (GMV hoặc commission)
  // - color: màu biểu đồ
  // Output: Widget biểu đồ
  Widget _buildChart(List<dynamic> data, double Function(dynamic) getValue, Color color, double px, ThemeData theme) {
    // Nếu không có dữ liệu thì hiển thị placeholder
    if (data.isEmpty) return const SizedBox(height: 200, child: Center(child: Text("Chưa có dữ liệu...")));

    // Convert data sang dạng điểm (x, y)
    final List<FlSpot> chartSpots = data
        .asMap()
        .entries
        .map((e) => FlSpot(
      e.key.toDouble(),
      getValue(e.value),
    ))
        .toList();

    return Container(
      height: 220,
      margin: const EdgeInsets.only(top: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,

              // Màu nền tooltip
              getTooltipColor: (LineBarSpot touchedSpot) => theme.cardColor.withOpacity(0.9),

              // Nội dung tooltip khi chạm vào điểm
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final index = touchedSpot.spotIndex;
                  final model = data[index];
                  final String dateRaw = model.date;

                  // Cache ngày đã format để tránh xử lý lại nhiều lần
                  if (!_dateCache.containsKey(dateRaw)) {
                    _dateCache[dateRaw] = DateFormat('dd/MM/yyyy').format(DateTime.parse(dateRaw));
                  }

                  return LineTooltipItem(
                    "${_dateCache[dateRaw]}\n",
                    TextStyle(color: Colors.grey, fontSize: 10 + px),
                    children: [
                      TextSpan(
                        text: currency.format(getValue(model)),
                        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13 + px),
                      ),
                    ],
                  );
                }).toList();
              },
            ),

            // Xử lý khi user tap vào biểu đồ
            touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
              if (event is FlTapDownEvent && touchResponse != null && touchResponse.lineBarSpots != null) {
                final index = touchResponse.lineBarSpots!.first.spotIndex;
                final model = data[index];

                // Hiển thị dialog chi tiết ngày
                _showTransactionDetails(context, model, color, px, theme);
              }
            },
            handleBuiltInTouches: true,
          ),

          // Hiển thị grid ngang
          gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(color: theme.dividerColor.withOpacity(0.1), strokeWidth: 1)),

          // Cấu hình trục X
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();

                  // Kiểm tra index hợp lệ
                  if (index < 0 || index >= data.length) return const SizedBox();

                  final dateRaw = data[index].date;

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      DateFormat('dd/MM').format(DateTime.parse(dateRaw)),
                      style: TextStyle(color: Colors.grey, fontSize: 10 + px),
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),

          // Cấu hình line chart
          lineBarsData: [
            LineChartBarData(
              spots: chartSpots,
              isCurved: true,
              color: color,
              barWidth: 4,

              // Hiển thị chấm trên line
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: color,
                ),
              ),

              // Vùng nền dưới line
              belowBarData: BarAreaData(show: true, color: color.withOpacity(0.15)),
            ),
          ],
        ),
      ),
    );
  }

  // Widget hiển thị thông tin shop trong danh sách ranking
  // Input: shop object
  // Output: Widget Card
  Widget _buildShopDrillDownCard(dynamic shop, double px, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)]),
      child: InkWell(
        onTap: () {
          // Điều hướng sang màn chi tiết shop
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdminShopDetailScreen(shopId: shop.id, shopName: shop.name)),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.store, color: Colors.white, size: 20)),
              const SizedBox(width: 15),

              // Tên shop
              Expanded(
                child: Text(
                  shop.name ?? 'Shop',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px),
                ),
              ),

              // Doanh thu shop
              Text(
                currency.format(shop.revenue ?? 0),
                style: TextStyle(fontWeight: FontWeight.w900, color: Colors.blue, fontSize: 14 + px),
              ),
              const SizedBox(width: 10),
              const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // Widget hiển thị tiêu đề section
  // Input: title, subtitle
  // Output: Widget
  Widget _buildSectionHeader(String title, String sub, double px) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15 + px))),
      Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(sub, style: TextStyle(color: Colors.grey, fontSize: 11 + px))),
    ],
  );

  // Hiển thị dialog chi tiết doanh thu theo ngày
  // Input: model dữ liệu ngày
  // Output: void
  void _showTransactionDetails(BuildContext context, dynamic model, Color themeColor, double px, ThemeData theme) {
    final String formattedDate = DateFormat('dd/MM/yyyy').format(DateTime.parse(model.date));

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: themeColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Báo cáo: $formattedDate",
                  style: TextStyle(color: Colors.white, fontSize: 15 + px, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: const Icon(Icons.close, color: Colors.white),
              )
            ],
          ),
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          height: 250,
          child: Column(
            children: [
              const SizedBox(height: 15),

              // Bảng hiển thị GMV và commission
              Table(
                border: TableBorder.all(color: Colors.grey.withOpacity(0.3)),
                columnWidths: const {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(2.5),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1)),
                    children: [
                      _buildCell("Chỉ số vận hành", isHeader: true, px: px),
                      _buildCell("Giá trị thực tế", isHeader: true, px: px),
                    ],
                  ),
                  TableRow(
                    children: [
                      _buildCell("Tổng doanh thu (GMV)", px: px),
                      _buildCell(currency.format(model.totalGmv), isAmount: true, px: px, color: Colors.blue),
                    ],
                  ),
                  TableRow(
                    children: [
                      _buildCell("Hoa hồng sàn (5%)", px: px),
                      _buildCell(currency.format(model.commission), isAmount: true, px: px, color: Colors.green),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  // Hàm build cell cho table
  // Input: text, flag header, flag amount
  // Output: Widget Text
  Widget _buildCell(String text, {bool isHeader = false, bool isAmount = false, required double px, Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Text(
        text,
        textAlign: isAmount ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: (isHeader ? 12 : 11) + px,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: color ?? (isHeader ? Colors.black87 : Colors.black54),
        ),
      ),
    );
  }
}
