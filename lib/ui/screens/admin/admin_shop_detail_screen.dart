import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/base_provider.dart';
import '../../../data/models/revenue_transaction_model.dart';

class AdminShopDetailScreen extends StatefulWidget {
  final int shopId;
  final String shopName;

  const AdminShopDetailScreen({super.key, required this.shopId, required this.shopName});

  @override
  State<AdminShopDetailScreen> createState() => _AdminShopDetailScreenState();
}

class _AdminShopDetailScreenState extends State<AdminShopDetailScreen> {
  /// Các bộ định dạng tĩnh giúp tối ưu hiệu năng render.
  static final NumberFormat _currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
  static final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormat = DateFormat('dd/MM');
  static final DateFormat _timeDateFormat = DateFormat('dd/MM HH:mm');

  /// Khoảng thời gian mặc định (7 ngày gần nhất).
  DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Chức năng: Gọi API lấy dữ liệu phân tích chi tiết của Shop được chọn.
  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<BaseProvider>().token;
      if (token == null) return;

      final startStr = _apiDateFormat.format(startDate);
      final endStr = _apiDateFormat.format(endDate);

      context.read<AdminProvider>().fetchShopDetailAnalytics(token, widget.shopId, startStr, endStr);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<AdminProvider, bool>((p) => p.isLoading);
    final chartData = context.select<AdminProvider, List<dynamic>>((p) => p.selectedShopChart);
    final txList = context.select<AdminProvider, List<RevenueTransactionModel>>((p) => p.selectedShopTx);

    final base = context.read<BaseProvider>();
    final px = base.textOffset;
    final isDark = base.isDarkMode;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(widget.shopName.toUpperCase(),
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16 + px, letterSpacing: 1)),
        elevation: 0,
        backgroundColor: theme.cardColor,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
        onRefresh: () async => _loadData(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildDateFilter(context, theme, px),
                  const SizedBox(height: 25),
                  _buildSectionHeader("Biến động doanh thu", "Nhấn vào điểm trên sơ đồ để xem số tiền cụ thể", px),
                  const SizedBox(height: 15),

                  /// ✅ NÂNG CẤP: Biểu đồ có khả năng tương tác và hiển thị rõ ràng.
                  _buildAdvancedChart(chartData, isDark, theme, px),

                  const SizedBox(height: 30),
                  _buildSectionHeader("Lịch sử giao dịch", "Các đơn hàng và dòng tiền của shop", px),
                  const SizedBox(height: 15),
                ]),
              ),
            ),
            _buildSliverTransactionList(txList, isDark, theme, px),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Tạo tiêu đề đoạn nội dung.
  Widget _buildSectionHeader(String title, String subtitle, double px) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17 + px)),
        Text(subtitle, style: TextStyle(color: Colors.grey, fontSize: 12 + px)),
      ],
    );
  }

  /// Chức năng: Bộ lọc thời gian báo cáo.
  Widget _buildDateFilter(BuildContext context, ThemeData theme, double px) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          const CircleAvatar(backgroundColor: Colors.blue, radius: 18, child: Icon(Icons.calendar_month, size: 18, color: Colors.white)),
          const SizedBox(width: 15),
          Expanded(
            child: GestureDetector(
              onTap: () => _selectDateRange(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Khoảng thời gian báo cáo", style: TextStyle(color: Colors.grey, fontSize: 11)),
                  Text(
                    "${_displayDateFormat.format(startDate)} - ${_displayDateFormat.format(endDate)}",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15 + px, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ),
          const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        ],
      ),
    );
  }

  /// Chức năng: Biểu đồ doanh thu chi tiết.
  /// ✅ TẠI SAO LÀM VẬY: Bật dotData và titlesData giúp Quản trị viên dễ dàng quan sát các mốc thời gian.
  Widget _buildAdvancedChart(List<dynamic> data, bool isDark, ThemeData theme, double px) {
    if (data.isEmpty) return const SizedBox(height: 200, child: Center(child: Text("Không có dữ liệu trong khoảng này")));

    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.totalGmv)).toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(5, 25, 20, 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => Colors.blueAccent.withOpacity(0.9),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
            ),
            /// ✅ CHỨC NĂNG: Bắt sự kiện nhấn vào điểm để hiện Popup tóm tắt[cite: 1, 10].
            touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
              if (event is FlTapDownEvent && touchResponse != null && touchResponse.lineBarSpots != null) {
                final index = touchResponse.lineBarSpots!.first.spotIndex;
                final model = data[index];
                _showDailyDetailPopup(context, model, isDark, px);
              }
            },
          ),
          /// ✅ NÂNG CẤP: Hiện lưới ngang mờ giúp định vị số tiền dễ hơn[cite: 1].
          gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.05))
          ),
          /// ✅ NÂNG CẤP: Hiện ngày tháng (dd/MM) ở trục dưới để Admin biết chính xác ngày nào[cite: 1].
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (val, meta) {
                  int index = val.toInt();
                  if (index >= 0 && index < data.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_displayDateFormat.format(DateTime.parse(data[index].date)),
                          style: TextStyle(color: Colors.grey, fontSize: 10 + px)),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blueAccent,
              barWidth: 4,
              /// ✅ NÂNG CẤP: Hiện điểm tròn tại các mốc dữ liệu[cite: 1].
              dotData: FlDotData(
                  show: true,
                  getDotPainter: (p0, p1, p2, p3) => FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 3, strokeColor: Colors.blueAccent)
              ),
              belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Hiển thị Popup báo cáo tóm tắt ngày (Dạng bảng Excel)[cite: 1, 10].
  /// ✅ TẠI SAO LÀM VẬY: Giúp Quản trị viên nắm nhanh số liệu GMV và Hoa hồng mà không cần chuyển màn hình[cite: 1].
  void _showDailyDetailPopup(BuildContext context, dynamic model, bool isDark, double px) {
    final String formattedDate = DateFormat('dd/MM/yyyy').format(DateTime.parse(model.date));

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Báo cáo: $formattedDate", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 + px)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              /// Bảng dữ liệu phong cách Excel[cite: 1].
              Table(
                border: TableBorder.all(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1)),
                    children: [
                      _buildCell("Hạng mục", isHeader: true, px: px),
                      _buildCell("Giá trị", isHeader: true, px: px),
                    ],
                  ),
                  TableRow(
                    children: [
                      _buildCell("Doanh thu (GMV)", px: px),
                      _buildCell(_currency.format(model.totalGmv), isAmount: true, px: px, color: Colors.blue),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 15),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCell(String text, {bool isHeader = false, bool isAmount = false, required double px, Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        textAlign: isAmount ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: (isHeader ? 13 : 12) + px,
          color: color,
        ),
      ),
    );
  }

  /// Chức năng: Danh sách lịch sử giao dịch dòng tiền.
  Widget _buildSliverTransactionList(List<RevenueTransactionModel> txs, bool isDark, ThemeData theme, double px) {
    if (txs.isEmpty) return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(40), child: Text("Không có giao dịch"))));

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final tx = txs[index];
            final isPositive = tx.amount > 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
                    child: Icon(isPositive ? Icons.add_circle_outline : Icons.remove_circle_outline,
                        color: isPositive ? Colors.green : Colors.red, size: 20),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx.typeLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px)),
                        Text(_timeDateFormat.format(tx.createdAt), style: TextStyle(color: Colors.grey, fontSize: 12 + px)),
                      ],
                    ),
                  ),
                  Text(
                    "${isPositive ? '+' : ''}${_currency.format(tx.amount)}",
                    style: TextStyle(fontWeight: FontWeight.w900, color: isPositive ? Colors.green : Colors.red, fontSize: 14 + px),
                  ),
                ],
              ),
            );
          },
          childCount: txs.length,
        ),
      ),
    );
  }

  /// Chức năng: Kích hoạt DateRangePicker hệ thống.
  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() { startDate = picked.start; endDate = picked.end; });
      _loadData();
    }
  }
}