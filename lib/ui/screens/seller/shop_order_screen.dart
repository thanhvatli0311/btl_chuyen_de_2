import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../data/models/order_model.dart';
import '../../../providers/shop_order_provider.dart';
import '../../../providers/base_provider.dart';
import 'order_detail_screen.dart';

/// Chức năng: Màn hình quản lý danh sách đơn hàng dành riêng cho chủ cửa hàng (Shop).
class ShopOrderScreen extends StatefulWidget {
  const ShopOrderScreen({super.key});

  @override
  State<ShopOrderScreen> createState() => _ShopOrderScreenState();
}

class _ShopOrderScreenState extends State<ShopOrderScreen> with SingleTickerProviderStateMixin {
  /// Bộ điều khiển dùng để quản lý việc chuyển đổi giữa các Tab trạng thái đơn hàng.
  late final TabController _tabController;

  /// Bộ định dạng tiền tệ tĩnh giúp hiển thị giá trị VND chuẩn xác trên toàn màn hình.
  static final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  /// Bản đồ ánh xạ dùng để dịch các mã trạng thái từ cơ sở dữ liệu sang tên hiển thị tiếng Việt.
  static const Map<String, String> _statusTranslations = {
    'pending': "Chờ duyệt",
    'confirmed': "Đã xác nhận",
    'shipping': "Đang giao",
    'delivered': "Hoàn tất",
    'cancelled': "Đã hủy",
    'returned': "Trả hàng",
  };

  /// Bản đồ quy định màu sắc đặc trưng cho từng loại trạng thái để người dùng dễ nhận diện.
  static const Map<String, Color> _statusColors = {
    'pending': Colors.orange,
    'confirmed': Colors.green,
    'shipping': Colors.purple,
    'delivered': Colors.blue,
    'cancelled': Colors.red,
  };

  /// Chức năng: Khởi tạo trạng thái ban đầu và thiết lập các bộ điều khiển cần thiết.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  @override
  void initState() {
    super.initState();
    /// Khởi tạo TabController với 4 mục tương ứng với 4 nhóm trạng thái hiển thị.
    _tabController = TabController(length: 4, vsync: this);
    /// Đăng ký hàm nạp dữ liệu đơn hàng ngay sau khi khung hình đầu tiên được dựng xong.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshOrders());
  }

  /// Chức năng: Giải phóng các bộ điều khiển khi màn hình bị đóng để tránh lãng phí bộ nhớ.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Chức năng: Thực hiện tải lại danh sách đơn hàng mới nhất từ phía máy chủ.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future không có giá trị trả về cụ thể.
  Future<void> _refreshOrders() async {
    /// Lấy mã xác thực (token) từ hệ thống quản lý trạng thái chung.
    final token = context.read<BaseProvider>().token;
    if (token != null) {
      /// Gọi hàm nạp dữ liệu của ShopOrderProvider để cập nhật danh sách đơn hàng.
      await context.read<ShopOrderProvider>().fetchOrders(token);
    }
  }

  /// Chức năng: Hỗ trợ chuyển đổi mã trạng thái thô sang tiếng Việt thông qua bản đồ ánh xạ.
  /// Tham số đầu vào: status - Mã trạng thái cần dịch.
  /// Giá trị trả về: Tên trạng thái bằng tiếng Việt.
  String _translateStatus(String status) => _statusTranslations[status] ?? status;

  /// Chức năng: Xây dựng cấu trúc giao diện chính bao gồm thanh tiêu đề và các nội dung Tab.
  /// Tham số đầu vào: context - Ngữ cảnh xây dựng của ứng dụng.
  /// Giá trị trả về: Widget Scaffold chứa toàn bộ giao diện màn hình.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseProvider = context.watch<BaseProvider>();
    final isDark = baseProvider.isDarkMode;

    /// Theo dõi sự thay đổi của ShopOrderProvider để lấy danh sách đơn hàng thực tế.
    final orderProvider = context.watch<ShopOrderProvider>();
    final allOrders = orderProvider.orders;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: const Text("QUẢN LÝ ĐƠN HÀNG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: theme.cardColor,
        elevation: 0,
        /// Thanh điều hướng Tab cho phép người dùng lọc đơn hàng theo tiến độ.
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: const Color(0xFF0047AB),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF0047AB),
          tabs: const [
            Tab(text: "Chờ duyệt"),
            Tab(text: "Đang xử lý"),
            Tab(text: "Hoàn tất"),
            Tab(text: "Đã hủy"),
          ],
        ),
      ),
      /// Hiển thị vòng xoay đang tải nếu hệ thống đang bận, ngược lại hiển thị danh sách đơn hàng.
      body: orderProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [
          /// Lọc và hiển thị danh sách đơn hàng theo từng TabView tương ứng.
          _buildOrderList(allOrders.where((o) => o.status == 'pending').toList(), isDark),
          _buildOrderList(allOrders.where((o) => o.status == 'confirmed' || o.status == 'shipping').toList(), isDark),
          _buildOrderList(allOrders.where((o) => o.status == 'delivered').toList(), isDark),
          _buildOrderList(allOrders.where((o) => o.status == 'cancelled' || o.status == 'returned').toList(), isDark),
        ],
      ),
    );
  }

  /// Chức năng: Tạo ra danh sách các đơn hàng có hỗ trợ tính năng kéo để tải lại (Pull to refresh).
  /// Tham số đầu vào: list - Mảng các đơn hàng đã được lọc, isDark - Chế độ giao diện tối/sáng.
  /// Giá trị trả về: Widget chứa danh sách các thẻ đơn hàng.
  Widget _buildOrderList(List<OrderModel> list, bool isDark) {
    /// Trả về thông báo nếu không tìm thấy đơn hàng nào trong bộ lọc này.
    if (list.isEmpty) {
      return Center(child: Text("Không có đơn hàng", style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _refreshOrders,
      child: ListView.builder(
        cacheExtent: 300,
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        itemBuilder: (context, index) => _buildOrderCard(list[index], isDark),
      ),
    );
  }

  /// Chức năng: Tạo giao diện chi tiết cho một đơn hàng cụ thể kèm theo các nút thao tác.
  /// Tham số đầu vào: order - Đối tượng đơn hàng, isDark - Chế độ giao diện tối/sáng.
  /// Giá trị trả về: Widget Container chứa thông tin đơn hàng.
  Widget _buildOrderCard(OrderModel order, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Hiển thị mã đơn hàng và nhãn trạng thái ở trên cùng của thẻ.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("#${order.code}",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0047AB))),
              _buildStatusBadge(order.status),
            ],
          ),
          const Divider(height: 24),
          /// Hiển thị tên người nhận hàng.
          Text("Khách hàng: ${order.address?.recipientName ?? 'N/A'}",
              style: const TextStyle(fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          /// Hiển thị số tiền cần thanh toán của đơn hàng.
          Text(_currencyFormat.format(order.totalAmount),
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),

          /// Khu vực các nút bấm hành động được sắp xếp tự động xuống dòng nếu thiếu không gian.
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 8, /// Khoảng cách ngang giữa các nút hành động.
              runSpacing: 8, /// Khoảng cách dọc khi các nút bị đẩy xuống dòng.
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                /// Nút cho phép hủy đơn hàng nếu đơn vẫn đang chờ hoặc vừa mới xác nhận.
                if (order.status == 'pending' || order.status == 'confirmed')
                  TextButton(
                    onPressed: () => _handleUpdateStatus(order.id, 'cancelled'),
                    child: const Text("HỦY ĐƠN", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),

                /// Nút để Shop duyệt đơn hàng mới gửi đến.
                if (order.status == 'pending')
                  _buildActionButton("DUYỆT ĐƠN", Colors.green, () => _handleUpdateStatus(order.id, 'confirmed')),

                /// Nút để chuyển sang giai đoạn vận chuyển.
                if (order.status == 'confirmed')
                  _buildActionButton("GIAO HÀNG", Colors.purple, () => _handleUpdateStatus(order.id, 'shipping')),

                /// Nút để xác nhận khách đã nhận hàng thành công.
                if (order.status == 'shipping')
                  _buildActionButton("HOÀN TẤT", Colors.blueAccent, () => _handleUpdateStatus(order.id, 'delivered')),

                /// Nút dẫn đến màn hình xem thông tin chi tiết đầy đủ của đơn hàng.
                OutlinedButton(
                  onPressed: () => _showOrderDetail(order),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.grey),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("CHI TIẾT", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  /// Chức năng: Tạo Widget nút bấm đồng nhất giúp giảm việc viết lại mã nguồn cho giao diện.
  /// Tham số đầu vào: label - Nhãn hiển thị, color - Màu nền nút, onPressed - Hàm thực thi khi nhấn.
  /// Giá trị trả về: Widget nút bấm ElevatedButton.
  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  /// Chức năng: Thực hiện việc chuyển hướng người dùng đến màn hình chi tiết đơn hàng.
  /// Tham số đầu vào: order - Đối tượng đơn hàng cần hiển thị.
  /// Giá trị trả về: Không có.
  void _showOrderDetail(OrderModel order) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)));
  }

  /// Chức năng: Gửi yêu cầu cập nhật trạng thái đơn hàng tới máy chủ thông qua Provider.
  /// Tham số đầu vào: id - ID của đơn hàng, status - Mã trạng thái mới.
  /// Giá trị trả về: Không có.
  void _handleUpdateStatus(int id, String status) async {
    final baseProvider = context.read<BaseProvider>();
    final token = baseProvider.token;
    if (token == null) return;

    /// Thực hiện gọi API cập nhật trạng thái.
    final success = await context.read<ShopOrderProvider>().changeStatus(id, status, token, baseProvider);

    /// Hiển thị thông báo kết quả cho người dùng nếu thao tác thành công.
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Thành công: ${_translateStatus(status)}"), duration: const Duration(seconds: 2)),
      );
    }
  }

  /// Chức năng: Tạo nhãn hiển thị trạng thái đơn hàng với màu sắc đặc trưng cho từng loại.
  /// Tham số đầu vào: status - Mã trạng thái hiện tại từ đơn hàng.
  /// Giá trị trả về: Widget nhãn trạng thái đã được định dạng.
  Widget _buildStatusBadge(String status) {
    /// Lấy màu sắc đã được định nghĩa sẵn cho trạng thái này.
    final color = _statusColors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(_translateStatus(status),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }
}