import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../data/models/order_model.dart';
import '../../../data/repositories/api_service.dart';
import '../../../providers/base_provider.dart';
import '../../../core/utils/image_helper.dart';
import 'order_detail_screen.dart';

class CustomerOrderScreen extends StatefulWidget {
  const CustomerOrderScreen({super.key});

  @override
  State<CustomerOrderScreen> createState() => _CustomerOrderScreenState();
}

class _CustomerOrderScreenState extends State<CustomerOrderScreen> {
  final ApiService _apiService = ApiService();

  /// Khai báo tĩnh bộ định dạng tiền tệ Việt Nam dùng chung cho toàn màn hình.
  /// Sử dụng static final để tối ưu tài nguyên, chỉ khởi tạo 1 lần duy nhất thay vì tạo mới ở mỗi lần Rebuild.
  static final NumberFormat _currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    /// Lấy thông tin trạng thái giao diện hiện tại (Sáng/Tối) từ BaseProvider.
    final isDark = context.watch<BaseProvider>().isDarkMode;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("ĐƠN MUA CỦA TÔI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          centerTitle: true,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.blueAccent,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(text: "Tất cả"),
              Tab(text: "Chờ xác nhận"),
              Tab(text: "Đang giao"),
              Tab(text: "Đã hoàn thành"),
              Tab(text: "Đã hủy"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildOrderList('all'),
            _buildOrderList('pending'),
            _buildOrderList('shipping'),
            _buildOrderList('delivered'),
            _buildOrderList('cancelled'),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Xây dựng và quản lý trạng thái nạp danh sách đơn hàng dựa trên bộ lọc.
  /// Tham số đầu vào: [status] - Chuỗi ký tự định danh trạng thái cần tải dữ liệu (ví dụ: 'all', 'pending').
  /// Giá trị trả về: Widget dạng danh sách cuộn (ListView) bọc trong FutureBuilder.
  Widget _buildOrderList(String status) {
    final token = context.read<BaseProvider>().token;

    return FutureBuilder<List<OrderModel>>(
      /// Thực hiện gọi API lấy danh sách đơn hàng của người dùng thông qua ApiService.
      future: _apiService.getCustomerOrders(token!, status: status),
      builder: (context, snapshot) {
        /// Hiển thị vòng xoay chờ đợi trong khi dữ liệu đang được tải từ máy chủ.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        /// Hiển thị thông báo nếu kết quả trả về rỗng hoặc không có dữ liệu.
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Chưa có đơn hàng nào.", style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          /// Cấu hình vùng đệm để ListView dựng sẵn các Card sắp xuất hiện, giúp cuộn mượt hơn.
          cacheExtent: 500,
          padding: const EdgeInsets.all(12),
          itemCount: snapshot.data!.length,
          itemBuilder: (context, index) => _buildOrderCard(snapshot.data![index]),
        );
      },
    );
  }

  /// Chức năng: Xây dựng giao diện hiển thị cho từng đơn hàng cụ thể trong danh sách.
  /// Tham số đầu vào: [order] - Đối tượng Model chứa thông tin chi tiết của đơn hàng.
  /// Giá trị trả về: Widget GestureDetector cho phép nhấn vào để xem chi tiết.
  Widget _buildOrderCard(OrderModel order) {
    final base = context.read<BaseProvider>();
    final isDark = base.isDarkMode;
    final double px = base.textOffset;

    return GestureDetector(
      onTap: () async {
        /// Điều hướng người dùng sang trang chi tiết đơn hàng.
        final refresh = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
        );
        /// Nếu người dùng có thao tác thay đổi dữ liệu (như hủy đơn) ở trang chi tiết, tiến hành làm mới UI.
        if (refresh == true) setState(() {});
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront, size: 18, color: Colors.blueAccent),
                const SizedBox(width: 8),
                /// Áp dụng độ lệch cỡ chữ (px) để đồng bộ với cài đặt cá nhân của người dùng.
                Text("Cửa hàng", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px)),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    order.shop?.name ?? "",
                    style: TextStyle(fontSize: 14 + px),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                    _getStatusText(order.status),
                    style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12)
                ),
              ],
            ),
            const Divider(height: 24),

            /// Duyệt qua danh sách các món hàng (items) có trong đơn để hiển thị thông tin sản phẩm.
            ...order.items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  ImageHelper.load(item.phone?.thumbnail, width: 60, height: 60, borderRadius: 8),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            item.phone?.title ?? "Sản phẩm",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14 + px)
                        ),
                        Text("x${item.quantity}", style: TextStyle(color: Colors.grey, fontSize: 12 + px)),
                      ],
                    ),
                  ),
                  Text(_currency.format(item.price), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px)),
                ],
              ),
            )),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                /// Định dạng ngày tháng năm của đơn hàng để hiển thị ngắn gọn.
                Text(DateFormat('dd/MM/yyyy').format(order.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                Flexible(
                  child: RichText(
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14 + px),
                          children: [
                            const TextSpan(text: "Tổng: "),
                            TextSpan(
                                text: _currency.format(order.totalAmount),
                                style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)
                            ),
                          ]
                      )
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Chuyển đổi các chuỗi trạng thái từ Database sang ngôn ngữ hiển thị thân thiện với người dùng.
  /// Tham số đầu vào: [status] - Chuỗi trạng thái kỹ thuật (pending, shipping, delivered, cancelled).
  /// Giá trị trả về: Chuỗi ký tự tiếng Việt đã được định dạng in hoa.
  String _getStatusText(String status) {
    switch(status) {
      case 'pending': return "CHỜ XÁC NHẬN";
      case 'shipping': return "ĐANG GIAO";
      case 'delivered': return "HOÀN THÀNH";
      case 'cancelled': return "ĐÃ HỦY";
      default: return status.toUpperCase();
    }
  }
}