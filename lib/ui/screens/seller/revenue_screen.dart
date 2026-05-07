import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../providers/revenue_provider.dart';
import '../../../providers/base_provider.dart';

class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  static final NumberFormat _currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
  static final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormat = DateFormat('dd/MM');
  static final DateFormat _timeDateFormat = DateFormat('dd/MM HH:mm');

  DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime endDate = DateTime.now();

  // Chức năng: Khởi tạo màn hình và tải dữ liệu sau khi frame đầu tiên được render.
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Chỉ gọi tải dữ liệu khi widget vẫn còn tồn tại trong cây widget.
      if (mounted) _loadData();
    });
  }

  // Chức năng: Tải dữ liệu thống kê doanh thu và lịch sử giao dịch từ provider.
  Future<void> _loadData() async {
    final base = context.read<BaseProvider>();
    final token = base.token;
    // Chỉ thực hiện gọi API khi token hợp lệ.
    if (token != null) {
      final startStr = _apiDateFormat.format(startDate);
      final endStr = _apiDateFormat.format(endDate);
      // Gọi song song hai API để giảm thời gian chờ dữ liệu.
      await Future.wait([
        context.read<RevenueProvider>().fetchRevenueStats(token, start: startStr, end: endStr),
        context.read<RevenueProvider>().fetchTransactions(token),
      ]);
    }
  }

  // Chức năng: Xây dựng giao diện chính của màn hình báo cáo tài chính.
  @override
  Widget build(BuildContext context) {
    final revProv = context.watch<RevenueProvider>();
    final base = context.watch<BaseProvider>();
    final isDark = base.isDarkMode;
    final px = base.textOffset;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text("BÁO CÁO TÀI CHÍNH",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18 + px, letterSpacing: 1)),
        elevation: 0,
        backgroundColor: theme.cardColor,
        centerTitle: true,
        actions: [
          // Nút tải lại toàn bộ dữ liệu.
          IconButton(onPressed: _loadData, icon: const Icon(Icons.analytics_outlined, color: Colors.blue)),
        ],
      ),
      body: revProv.isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildDateFilter(context, theme, px),
                  const SizedBox(height: 10),
                  _buildQuickStats(revProv, px, isDark, theme),
                  const SizedBox(height: 25),
                  _buildSectionHeader("Biến động doanh thu", "Nhấn vào để xem chi tiết", px),
                  const SizedBox(height: 15),

                  // Biểu đồ doanh thu hiển thị biến động theo thời gian.
                  _buildAdvancedChart(revProv, isDark, theme, px),

                  const SizedBox(height: 30),
                  _buildSectionHeader("Lịch sử dòng tiền", "Các giao dịch gần đây", px),
                  const SizedBox(height: 15),
                ]),
              ),
            ),
            _buildSliverTransactionList(revProv, isDark, theme, px),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  // Chức năng: Tạo biểu đồ doanh thu có hỗ trợ chạm để xem chi tiết từng ngày.
  Widget _buildAdvancedChart(RevenueProvider prov, bool isDark, ThemeData theme, double px) {
    final chartData = prov.stats?.chartData ?? [];
    // Nếu chưa có dữ liệu thì hiển thị trạng thái chờ.
    if (chartData.isEmpty) return const SizedBox(height: 200, child: Center(child: Text("Đang tổng hợp dữ liệu...")));

    final List<Color> gradientColors = [Colors.blueAccent, const Color(0xFF00F2FE)];
    // Chuyển danh sách dữ liệu sang dạng điểm để fl_chart xử lý.
    final List<FlSpot> spots = chartData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.revenue)).toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(5, 20, 15, 5),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20)],
      ),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              // Màu tooltip thay đổi theo giao diện sáng/tối.
              getTooltipColor: (spot) => isDark ? const Color(0xFF2D3748) : Colors.white,
              tooltipRoundedRadius: 12,
            ),
            touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
              // Khi người dùng chạm vào một điểm dữ liệu thì mở popup chi tiết.
              if (event is FlTapDownEvent && touchResponse != null && touchResponse.lineBarSpots != null) {
                final index = touchResponse.lineBarSpots!.first.spotIndex;
                final model = chartData[index];
                _showDailyDetailPopup(context, model, isDark, px);
              }
            },
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            // Chỉ hiển thị lưới ngang để dễ quan sát mức doanh thu.
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (val, meta) {
                  // Không hiển thị mốc 0 để biểu đồ gọn hơn.
                  if (val == 0) return const SizedBox();
                  // Rút gọn số tiền lớn thành đơn vị k hoặc M.
                  String text = val >= 1000000 ? '${(val / 1000000).toStringAsFixed(1)}M' : '${(val / 1000).toInt()}k';
                  return Text(text, style: TextStyle(color: Colors.grey, fontSize: 9 + px));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (val, meta) {
                  int index = val.toInt();
                  // Chỉ hiển thị cách một mốc để tránh chữ bị dày đặc.
                  if (index % 2 == 0 && index < chartData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(chartData[index].date.substring(0, 5), style: TextStyle(color: Colors.grey, fontSize: 9 + px)),
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
              gradient: LinearGradient(colors: gradientColors),
              barWidth: 4,
              dotData: FlDotData(
                show: true,
                // Hiển thị điểm tròn tại từng mốc dữ liệu để dễ chạm chọn.
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: Colors.blueAccent
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                // Tô nền mờ phía dưới đường biểu đồ để tăng trực quan.
                gradient: LinearGradient(
                  colors: gradientColors.map((color) => color.withOpacity(0.15)).toList(),
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Chức năng: Hiển thị popup chi tiết doanh thu của ngày được chọn.
  void _showDailyDetailPopup(BuildContext context, dynamic model, bool isDark, double px) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Báo cáo: ${model.date}", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 + px)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dùng Table để dữ liệu hiển thị thẳng hàng và dễ đọc.
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
                      _buildCell("Doanh thu", px: px),
                      _buildCell(_currency.format(model.revenue), isPositive: true, px: px),
                    ],
                  ),
                  TableRow(
                    children: [
                      _buildCell("Trạng thái", px: px),
                      _buildCell("Hoàn thành", px: px),
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

  // Chức năng: Tạo một ô dữ liệu dùng trong bảng chi tiết.
  Widget _buildCell(String text, {bool isHeader = false, bool isPositive = false, required double px}) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        text,
        textAlign: isHeader ? TextAlign.center : TextAlign.left,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: (isHeader ? 13 : 12) + px,
          color: isPositive ? Colors.green : null,
        ),
      ),
    );
  }

  // Chức năng: Tạo tiêu đề cho từng khối nội dung trong màn hình.
  Widget _buildSectionHeader(String title, String subtitle, double px) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17 + px)),
        Text(subtitle, style: TextStyle(color: Colors.grey, fontSize: 12 + px)),
      ],
    );
  }

  // Chức năng: Hiển thị bộ lọc khoảng thời gian báo cáo.
  Widget _buildDateFilter(BuildContext context, ThemeData theme, double px) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const CircleAvatar(backgroundColor: Colors.blue, radius: 18, child: Icon(Icons.calendar_month, size: 18, color: Colors.white)),
          const SizedBox(width: 15),
          Expanded(
            child: GestureDetector(
              // Khi nhấn vào vùng ngày sẽ mở bộ chọn khoảng thời gian.
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

  // Chức năng: Hiển thị các chỉ số tổng quan quan trọng.
  Widget _buildQuickStats(RevenueProvider prov, double px, bool isDark, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 20)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Doanh thu thực nhận", style: TextStyle(color: Colors.grey, fontSize: 13 + px)),
                      const SizedBox(height: 8),
                      Text(_currency.format(prov.stats?.totalRevenue ?? 0),
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24 + px, color: Colors.blue)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            // Mũi tên thay đổi theo chiều tăng hoặc giảm doanh thu.
                            (prov.stats?.growthRate ?? 0) >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                            color: (prov.stats?.growthRate ?? 0) >= 0 ? Colors.green : Colors.red,
                            size: 14,
                          ),
                          Text(
                            " ${prov.stats?.growthRate ?? 0}% so với tháng trước",
                            style: TextStyle(
                              color: (prov.stats?.growthRate ?? 0) >= 0 ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12 + px,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
                const Icon(Icons.bar_chart_rounded, size: 40, color: Colors.blueAccent),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statCard("Số dư hiện có", _currency.format(prov.stats?.currentBalance ?? 0),
                  const Color(0xFF4FACFE), const Color(0xFF00F2FE), Icons.account_balance_wallet, theme, px)),
              const SizedBox(width: 12),
              Expanded(child: _statCard("Đơn hàng thành công", "${prov.stats?.totalOrders ?? 0}",
                  const Color(0xFFFAD961), const Color(0xFFF76B1C), Icons.shopping_bag, theme, px)),
            ],
          ),
        ],
      ),
    );
  }

  // Chức năng: Tạo thẻ thống kê nhỏ dùng cho các chỉ số phụ.
  Widget _statCard(String label, String value, Color c1, Color c2, IconData icon, ThemeData theme, double px) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: c1.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [c1, c2]), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(height: 15),
          Text(label, style: TextStyle(color: Colors.grey, fontSize: 11 + px)),
          const SizedBox(height: 4),
          FittedBox(child: Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16 + px))),
        ],
      ),
    );
  }

  // Chức năng: Hiển thị danh sách lịch sử giao dịch dạng Sliver.
  Widget _buildSliverTransactionList(RevenueProvider prov, bool isDark, ThemeData theme, double px) {
    // Nếu không có giao dịch thì hiển thị trạng thái rỗng.
    if (prov.transactions.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(24)),
          child: const Column(children: [Icon(Icons.history, color: Colors.grey, size: 40), SizedBox(height: 10), Text("Không tìm thấy giao dịch", style: TextStyle(color: Colors.grey))]),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final tx = prov.transactions[index];
            // Giá trị dương là tiền vào, âm là tiền ra.
            final isPositive = tx.amount > 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
                    child: Icon(isPositive ? Icons.add_circle_outline : Icons.remove_circle_outline, color: isPositive ? Colors.green : Colors.red, size: 20),
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
          childCount: prov.transactions.length,
        ),
      ),
    );
  }

  // Chức năng: Mở hộp thoại chọn khoảng ngày và cập nhật dữ liệu.
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context, initialDateRange: DateTimeRange(start: startDate, end: endDate), firstDate: DateTime(2023), lastDate: DateTime.now(),
    );
    // Khi người dùng chọn ngày hợp lệ thì cập nhật state và tải lại dữ liệu.
    if (picked != null) {
      setState(() { startDate = picked.start; endDate = picked.end; });
      _loadData();
    }
  }
}
