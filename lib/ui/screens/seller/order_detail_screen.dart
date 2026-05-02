import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../data/models/order_model.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/shop_order_provider.dart';

class OrderDetailScreen extends StatelessWidget {
  final OrderModel order;
  const OrderDetailScreen({super.key, required this.order});

  /// Bộ định dạng tiền tệ Việt Nam dùng chung.
  /// Khai báo tĩnh để khởi tạo duy nhất một lần, giúp tiết kiệm CPU khi vẽ lại giao diện.
  static final NumberFormat _currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  /// Chức năng: Chuyển đổi mã trạng thái tiếng Anh từ hệ thống sang ngôn ngữ hiển thị tiếng Việt.
  /// Tham số đầu vào: [status] - Chuỗi trạng thái kỹ thuật (pending, shipping...).
  /// Giá trị trả về: Chuỗi tiếng Việt đã được định dạng in hoa.
  String _translateStatus(String status) {
    switch (status) {
      case 'pending': return "CHỜ DUYỆT";
      case 'confirmed': return "ĐÃ XÁC NHẬN";
      case 'shipping': return "ĐANG GIAO HÀNG";
      case 'delivered': return "GIAO THÀNH CÔNG";
      case 'cancelled': return "ĐÃ HỦY";
      case 'returned': return "TRẢ HÀNG";
      default: return status.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    /// Sử dụng context.select để chỉ lắng nghe sự thay đổi của chế độ tối (isDarkMode).
    /// Điều này giúp màn hình không bị rebuild vô ích khi các dữ liệu khác trong Provider thay đổi.
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Text("CHI TIẾT #${order.code}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: theme.cardColor,
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SingleChildScrollView(
        /// Sử dụng hiệu ứng cuộn vật lý mượt mà cho trải nghiệm người dùng Android.
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Phần đầu trang hiển thị trạng thái hiện tại của đơn hàng.
            _buildStatusHeader(order.status),
            const SizedBox(height: 20),
            _buildSectionTitle("Thông tin khách hàng", isDark),
            _buildInfoCard(order.address, theme),
            const SizedBox(height: 20),
            _buildSectionTitle("Sản phẩm", isDark),

            /// Duyệt qua danh sách món hàng và sử dụng toán tử Spread (...) để đưa các Widget vào Column.
            ...order.items.map((item) => _buildProductItem(item, theme)),

            const SizedBox(height: 20),
            _buildSummary(order, theme),
            const SizedBox(height: 100),
          ],
        ),
      ),
      /// Thanh công cụ phía dưới cùng để người bán thực hiện các thao tác xác nhận đơn.
      bottomSheet: _buildBottomAction(context, isDark),
    );
  }

  /// Chức năng: Xây dựng khung hiển thị trạng thái đơn hàng nổi bật.
  /// Tham số đầu vào: [status] - Trạng thái hiện tại của đơn hàng.
  /// Giá trị trả về: Widget khung thông tin (Container).
  Widget _buildStatusHeader(String status) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12)
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.blue),
          const SizedBox(width: 12),
          Text("TRẠNG THÁI: ${_translateStatus(status)}",
              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  /// Chức năng: Tạo nhãn tiêu đề cho từng phân đoạn thông tin.
  /// Tham số đầu vào: [title] (nội dung), [isDark].
  /// Giá trị trả về: Widget văn bản định dạng nhỏ.
  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(title,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white70 : Colors.black54
          )
      ),
    );
  }

  /// Chức năng: Hiển thị thẻ thông tin liên hệ và địa chỉ của người nhận hàng.
  /// Tham số đầu vào: [address] dữ liệu địa chỉ, [theme] chủ đề.
  /// Giá trị trả về: Widget khung thông tin khách hàng.
  Widget _buildInfoCard(dynamic address, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Kết hợp tên người nhận và số điện thoại trên cùng một dòng.
          Text(
              "${address?.recipientName ?? 'N/A'} | ${address?.phone ?? 'N/A'}",
              style: const TextStyle(fontWeight: FontWeight.bold)
          ),
          const Divider(),
          /// Hiển thị chi tiết địa chỉ giao hàng.
          Text(
              "${address?.detail ?? ''}, ${address?.ward ?? ''}, ${address?.district ?? ''}, ${address?.province ?? ''}",
              style: const TextStyle(fontSize: 13, height: 1.4)
          ),
        ],
      ),
    );
  }

  /// Chức năng: Tạo giao diện hàng hiển thị thông tin từng sản phẩm cụ thể.
  /// Tham số đầu vào: [item] dữ liệu món hàng, [theme].
  /// Giá trị trả về: Widget hàng sản phẩm.
  Widget _buildProductItem(dynamic item, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          /// Hiển thị hình ảnh thu nhỏ của máy kèm xử lý lỗi nếu ảnh không tải được.
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 50, height: 50, color: Colors.grey[200],
              child: item.phone?.thumbnailUrl != null
                  ? Image.network(item.phone!.thumbnailUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.phone_android, size: 20))
                  : const Icon(Icons.phone_android, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(item.phone?.title ?? "Sản phẩm không xác định",
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text("x${item.quantity}", style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 12),
          Text(_currency.format(item.price),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0047AB))),
        ],
      ),
    );
  }

  /// Chức năng: Hiển thị tóm tắt tổng số tiền người mua cần thanh toán.
  /// Tham số đầu vào: [order] đơn hàng, [theme].
  /// Giá trị trả về: Widget hàng tổng cộng.
  Widget _buildSummary(OrderModel order, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Tổng thanh toán", style: TextStyle(fontWeight: FontWeight.bold)),
          Text(_currency.format(order.totalAmount),
              style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
    );
  }

  /// Chức năng: Quyết định hiển thị các nút hành động (Xác nhận, Giao hàng...) dựa trên trạng thái đơn.
  /// Tham số đầu vào: [context], [isDark].
  /// Giá trị trả về: Widget thanh thao tác (Container) hoặc ô trống nếu đơn đã kết thúc.
  Widget _buildBottomAction(BuildContext context, bool isDark) {
    /// Không hiển thị nút nếu đơn đã hoàn thành hoặc đã bị hủy/trả hàng.
    if (order.status == 'delivered' || order.status == 'cancelled' || order.status == 'returned') {
      return const SizedBox.shrink();
    }

    String btnText = "";
    String nextStatus = "";
    Color btnColor = Colors.blue;

    /// Phân tích trạng thái hiện tại để chuyển sang trạng thái kế tiếp trong quy trình bán hàng.
    if (order.status == 'pending') { btnText = "XÁC NHẬN ĐƠN"; nextStatus = "confirmed"; btnColor = Colors.green; }
    else if (order.status == 'confirmed') { btnText = "GIAO HÀNG"; nextStatus = "shipping"; btnColor = Colors.purple; }
    else if (order.status == 'shipping') { btnText = "GIAO THÀNH CÔNG"; nextStatus = "delivered"; btnColor = Colors.orange; }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)))
      ),
      child: Row(
        children: [
          /// Nút Hủy đơn luôn hiển thị nếu đơn chưa kết thúc.
          Expanded(
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red), minimumSize: const Size(0, 50)),
              onPressed: () => _confirmCancel(context),
              child: const Text("HỦY ĐƠN", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 12),
          /// Nút cập nhật trạng thái bước tiếp theo.
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: btnColor, minimumSize: const Size(0, 50), elevation: 0),
              onPressed: () => _update(context, nextStatus),
              child: Text(btnText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  /// Chức năng: Thực hiện lệnh gọi API để thay đổi trạng thái của đơn hàng trên máy chủ.
  /// Tham số đầu vào: [context], [status] - Trạng thái mới cần cập nhật.
  /// Giá trị trả về: Không có (Sử dụng bất đồng bộ).
  void _update(BuildContext context, String status) async {
    final base = context.read<BaseProvider>();
    final token = base.token;
    if (token == null) return;

    /// Gọi hàm đổi trạng thái trong ShopOrderProvider.
    final success = await context.read<ShopOrderProvider>().changeStatus(order.id, status, token, base);

    /// Sau khi API phản hồi, kiểm tra xem màn hình còn hiển thị hay không trước khi điều hướng.
    if (success && context.mounted) {
      if (status == 'delivered') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Giao hàng thành công! Tiền đã về ví.")));
      }
      Navigator.pop(context);
    }
  }

  /// Chức năng: Hiển thị hộp thoại cảnh báo để người bán xác nhận việc hủy đơn.
  /// Tham số đầu vào: [context].
  /// Giá trị trả về: Không có.
  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận hủy"),
        content: const Text("Bạn có chắc chắn muốn hủy đơn hàng này? Sản phẩm sẽ được hoàn lại kho."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              /// Tiến hành cập nhật trạng thái đơn thành 'cancelled'.
              _update(context, 'cancelled');
            },
            child: const Text("XÁC NHẬN HỦY", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}