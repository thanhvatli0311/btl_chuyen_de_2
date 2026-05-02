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
  /// Các bộ định dạng (Formatters) tĩnh dùng chung để tối ưu hiệu năng.
  /// Khởi tạo duy nhất một lần thay vì khởi tạo lại mỗi khi hàm build chạy.
  static final NumberFormat _currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
  static final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormat = DateFormat('dd/MM');
  static final DateFormat _timeDateFormat = DateFormat('dd/MM HH:mm');

  /// Khoảng thời gian mặc định để lọc dữ liệu (từ 7 ngày trước đến hiện tại).
  DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    /// Tự động nạp dữ liệu ngay khi màn hình khởi tạo.
    _loadData();
  }

  /// Chức năng: Gọi API để lấy dữ liệu thống kê chi tiết của một cửa hàng cụ thể.
  /// Tham số đầu vào: Không có (Sử dụng dữ liệu từ biến trạng thái của Class).
  /// Giá trị trả về: Không có.
  void _loadData() {
    /// Đảm bảo Context đã sẵn sàng bằng cách đợi sau khi khung hình được vẽ.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<BaseProvider>().token;
      if (token == null) return;

      /// Chuyển đổi ngày tháng sang định dạng chuỗi theo yêu cầu của API Backend.
      final startStr = _apiDateFormat.format(startDate);
      final endStr = _apiDateFormat.format(endDate);

      /// Thực hiện yêu cầu lấy dữ liệu thông qua Provider.
      context.read<AdminProvider>().fetchShopDetailAnalytics(token, widget.shopId, startStr, endStr);
    });
  }

  @override
  Widget build(BuildContext context) {
    /// Lắng nghe sự thay đổi của các biến cụ thể trong AdminProvider để Rebuild chính xác.
    final isLoading = context.select<AdminProvider, bool>((p) => p.isLoading);
    final chartData = context.select<AdminProvider, List<dynamic>>((p) => p.selectedShopChart);
    final txList = context.select<AdminProvider, List<RevenueTransactionModel>>((p) => p.selectedShopTx);

    /// Lấy các cấu hình giao diện chung từ BaseProvider.
    final base = context.read<BaseProvider>();
    final px = base.textOffset;
    final isDark = base.isDarkMode;
    final theme = Theme.of(context);

    return Scaffold(
      /// Tự động đổi màu nền dựa theo chế độ Sáng/Tối.
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
        /// Tính năng kéo từ trên xuống để làm mới dữ liệu.
        onRefresh: () async => _loadData(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  /// Thành phần lọc ngày tháng.
                  _buildDateFilter(context, theme, px),
                  const SizedBox(height: 25),
                  /// Tiêu đề phần biểu đồ.
                  _buildSectionHeader("Biến động doanh thu", "Dữ liệu GMV của shop", px),
                  const SizedBox(height: 15),
                  /// Thành phần biểu đồ đường.
                  _buildAdvancedChart(chartData, isDark, theme, px),
                  const SizedBox(height: 30),
                  /// Tiêu đề phần danh sách giao dịch.
                  _buildSectionHeader("Lịch sử giao dịch", "Các đơn hàng và dòng tiền của shop", px),
                  const SizedBox(height: 15),
                ]),
              ),
            ),
            /// Danh sách các giao dịch dòng tiền dạng Sliver.
            _buildSliverTransactionList(txList, isDark, theme, px),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Tạo tiêu đề cho từng phân đoạn (Section) trên giao diện.
  /// Tham số đầu vào: [title] (tiêu đề chính), [subtitle] (mô tả phụ), [px] (cỡ chữ).
  /// Giá trị trả về: Widget dạng Column.
  Widget _buildSectionHeader(String title, String subtitle, double px) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17 + px)),
        Text(subtitle, style: TextStyle(color: Colors.grey, fontSize: 12 + px)),
      ],
    );
  }

  /// Chức năng: Xây dựng thanh công cụ hiển thị khoảng ngày đang được lọc.
  /// Tham số đầu vào: [context], [theme], [px].
  /// Giá trị trả về: Widget cho phép người dùng nhấn để chọn ngày.
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
              /// Mở hộp thoại chọn khoảng ngày.
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

  /// Chức năng: Vẽ biểu đồ đường thể hiện sự thay đổi doanh thu theo thời gian.
  /// Tham số đầu vào: [data] (danh sách doanh thu theo ngày), [isDark], [theme], [px].
  /// Giá trị trả về: Widget chứa biểu đồ LineChart.
  Widget _buildAdvancedChart(List<dynamic> data, bool isDark, ThemeData theme, double px) {
    if (data.isEmpty) return const SizedBox(height: 200, child: Center(child: Text("Không có dữ liệu trong khoảng này")));

    /// Chuyển đổi dữ liệu từ API sang các điểm tọa độ (X, Y) trên biểu đồ.
    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.totalGmv)).toList();

    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(10, 25, 20, 10),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(28)),
      child: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                /// Cấu hình hiển thị thông tin khi người dùng nhấn vào các điểm trên biểu đồ.
                getTooltipColor: (spot) => Colors.blueAccent.withOpacity(0.8),
                fitInsideHorizontally: true,
                fitInsideVertically: true,
              )
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.05))),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: Colors.blueAccent,
              barWidth: 4,
              dotData: FlDotData(show: true, getDotPainter: (p0, p1, p2, p3) => FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 3, strokeColor: Colors.blueAccent)),
              belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withOpacity(0.1)),
            ),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Hiển thị danh sách lịch sử giao dịch dưới dạng danh sách Sliver tối ưu.
  /// Tham số đầu vào: [txs] (danh sách model giao dịch), [isDark], [theme], [px].
  /// Giá trị trả về: Widget SliverList giúp tối ưu bộ nhớ khi cuộn.
  Widget _buildSliverTransactionList(List<RevenueTransactionModel> txs, bool isDark, ThemeData theme, double px) {
    if (txs.isEmpty) return const SliverToBoxAdapter(child: Center(child: Text("Không có giao dịch")));

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) {
            final tx = txs[index];
            /// Xác định giao dịch là dòng tiền vào (+) hay dòng tiền ra (-).
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
                        /// Hiển thị tên loại giao dịch và thời gian tạo.
                        Text(tx.typeLabel, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px)),
                        Text(_timeDateFormat.format(tx.createdAt), style: TextStyle(color: Colors.grey, fontSize: 12 + px)),
                      ],
                    ),
                  ),
                  /// Hiển thị số tiền giao dịch kèm định dạng VNĐ.
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

  /// Chức năng: Hiển thị giao diện chọn khoảng ngày từ lịch hệ thống.
  /// Tham số đầu vào: [context].
  /// Giá trị trả về: Future<void>.
  Future<void> _selectDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: startDate, end: endDate),
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    /// Nếu người dùng chọn ngày xong, cập nhật lại biến trạng thái và tải lại dữ liệu.
    if (picked != null) {
      setState(() { startDate = picked.start; endDate = picked.end; });
      _loadData();
    }
  }
}