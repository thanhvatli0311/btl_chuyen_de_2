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
  /// Bộ định dạng tĩnh dùng chung cho tiền tệ và thời gian.
  /// Khai báo static final giúp tránh khởi tạo lại các đối tượng nặng này trong mỗi lần Build.
  static final NumberFormat _currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
  static final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormat = DateFormat('dd/MM');
  static final DateFormat _timeDateFormat = DateFormat('dd/MM HH:mm');

  DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    /// Nạp dữ liệu thống kê ngay khi màn hình vừa được khởi tạo.
    _loadData();
  }

  /// Chức năng: Gọi các API cần thiết để nạp dữ liệu thống kê và lịch sử giao dịch.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void> xử lý bất đồng bộ.
  Future<void> _loadData() async {
    final base = context.read<BaseProvider>();
    final token = base.token;
    if (token != null) {
      final startStr = _apiDateFormat.format(startDate);
      final endStr = _apiDateFormat.format(endDate);

      /// Thực hiện chạy song song hai yêu cầu mạng (Stats và Transactions) để giảm thời gian chờ đợi.
      await Future.wait([
        context.read<RevenueProvider>().fetchRevenueStats(token, start: startStr, end: endStr),
        context.read<RevenueProvider>().fetchTransactions(token),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    /// Lắng nghe các thay đổi về dữ liệu và cấu hình giao diện từ Provider.
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
          IconButton(onPressed: _loadData, icon: const Icon(Icons.analytics_outlined, color: Colors.blue)),
        ],
      ),
      body: revProv.isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
        onRefresh: _loadData,
        /// Sử dụng CustomScrollView để tối ưu hóa hiệu năng render cho danh sách dài.
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
                  _buildSectionHeader("Biến động doanh thu", "So với mốc thời gian trước", px),
                  const SizedBox(height: 15),
                  _buildAdvancedChart(revProv, isDark, theme, px),
                  const SizedBox(height: 30),
                  _buildSectionHeader("Lịch sử dòng tiền", "Các giao dịch gần đây", px),
                  const SizedBox(height: 15),
                ]),
              ),
            ),
            /// Danh sách các giao dịch gần đây được render dưới dạng Sliver (Lazy Loading).
            _buildSliverTransactionList(revProv, isDark, theme, px),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Tạo phần tiêu đề cho mỗi đoạn nội dung lớn trong trang.
  /// Tham số đầu vào: [title] tiêu đề chính, [subtitle] phụ đề mô tả, [px] độ lệch cỡ chữ.
  /// Giá trị trả về: Widget chứa text tiêu đề.
  Widget _buildSectionHeader(String title, String subtitle, double px) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17 + px)),
        Text(subtitle, style: TextStyle(color: Colors.grey, fontSize: 12 + px)),
      ],
    );
  }

  /// Chức năng: Xây dựng thanh chọn khoảng thời gian báo cáo.
  /// Tham số đầu vào: [context], [theme], [px].
  /// Giá trị trả về: Widget dạng thanh ngang có thể nhấn vào.
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

  /// Chức năng: Xây dựng khu vực hiển thị các chỉ số tóm tắt nhanh (Doanh thu, tăng trưởng).
  /// Tham số đầu vào: [prov] provider dữ liệu, [px], [isDark], [theme].
  /// Giá trị trả về: Widget chứa các thẻ chỉ số chính.
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
                            /// Xác định hướng mũi tên dựa trên tỉ lệ tăng trưởng.
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

  /// Chức năng: Thành phần thẻ con dùng để hiển thị một chỉ số cụ thể với màu sắc Gradient.
  /// Tham số đầu vào: [label] tên nhãn, [value] giá trị, [c1], [c2] màu dải màu, [icon], [theme], [px].
  /// Giá trị trả về: Widget thẻ thống kê thu nhỏ.
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

  /// Chức năng: Xây dựng biểu đồ đường nâng cao hiển thị dữ liệu doanh thu biến thiên.
  /// Tham số đầu vào: [prov] provider, [isDark], [theme], [px].
  /// Giá trị trả về: Widget biểu đồ bọc trong khung trang trí.
  Widget _buildAdvancedChart(RevenueProvider prov, bool isDark, ThemeData theme, double px) {
    final chartData = prov.stats?.chartData ?? [];
    if (chartData.isEmpty) return const SizedBox(height: 200, child: Center(child: Text("Đang tổng hợp dữ liệu...")));

    final List<Color> gradientColors = [Colors.blueAccent, const Color(0xFF00F2FE)];

    /// Ánh xạ dữ liệu thô sang các điểm dữ liệu (spots) để vẽ trên biểu đồ.
    final List<FlSpot> spots = chartData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.revenue)).toList();

    return Container(
      height: 350,
      padding: const EdgeInsets.fromLTRB(10, 20, 20, 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (spot) => isDark ? const Color(0xFF2D3748) : Colors.white,
              tooltipRoundedRadius: 12,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                /// Tùy biến nội dung hiển thị khi chạm vào từng điểm trên biểu đồ.
                return touchedSpots.map((LineBarSpot touchedSpot) {
                  final model = chartData[touchedSpot.spotIndex];
                  return LineTooltipItem(
                    "${model.date}\n",
                    TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 10 + px),
                    children: [
                      TextSpan(
                        text: _currency.format(model.revenue),
                        style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14 + px),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(isDark ? 0.05 : 0.1), strokeWidth: 1),
            getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.withOpacity(isDark ? 0.05 : 0.1), strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                getTitlesWidget: (val, meta) {
                  /// Rút gọn các con số lớn (Ví dụ: 1M thay vì 1.000.000).
                  if (val == 0) return const SizedBox();
                  String text = val >= 1000000 ? '${(val / 1000000).toStringAsFixed(1)}M' : '${(val / 1000).toInt()}k';
                  return Text(text, style: TextStyle(color: Colors.grey, fontSize: 10 + px, fontWeight: FontWeight.bold));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (val, meta) {
                  int index = val.toInt();
                  /// Chỉ hiển thị một số mốc ngày nhất định để tránh làm biểu đồ bị rối.
                  if (index == 0 || index == chartData.length ~/ 2 || index == chartData.length - 1) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(chartData[index].date.substring(0, 5), style: TextStyle(color: Colors.grey, fontSize: 10 + px, fontWeight: FontWeight.bold)),
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
              curveSmoothness: 0.35,
              gradient: LinearGradient(colors: gradientColors),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 3, color: Colors.white, strokeWidth: 2, strokeColor: Colors.blueAccent),
                /// Chỉ hiển thị chấm tại điểm dữ liệu mới nhất.
                checkToShowDot: (spot, barData) => spot.x == chartData.length - 1,
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: gradientColors.map((color) => color.withOpacity(0.2)).toList(),
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Xây dựng danh sách lịch sử các giao dịch tài chính theo kiểu Lazy Loading.
  /// Tham số đầu vào: [prov] provider, [isDark], [theme], [px].
  /// Giá trị trả về: Widget SliverList dùng cho CustomScrollView.
  Widget _buildSliverTransactionList(RevenueProvider prov, bool isDark, ThemeData theme, double px) {
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
                        /// Hiển thị tên loại giao dịch và thời gian thực hiện.
                        Text(tx.typeLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px)),
                        Text(_timeDateFormat.format(tx.createdAt), style: TextStyle(color: Colors.grey, fontSize: 12 + px)),
                      ],
                    ),
                  ),
                  /// Hiển thị số tiền tăng (+) hoặc giảm (-) kèm định dạng màu sắc.
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

  /// Chức năng: Kích hoạt hộp thoại chọn khoảng ngày (Date Range Picker) từ hệ thống.
  /// Tham số đầu vào: [context].
  /// Giá trị trả về: Future<void>.
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context, initialDateRange: DateTimeRange(start: startDate, end: endDate), firstDate: DateTime(2023), lastDate: DateTime.now(),
    );
    if (picked != null) {
      /// Cập nhật trạng thái ngày và nạp lại dữ liệu thống kê mới.
      setState(() { startDate = picked.start; endDate = picked.end; });
      _loadData();
    }
  }
}