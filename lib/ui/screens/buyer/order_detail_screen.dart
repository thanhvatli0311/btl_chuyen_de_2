import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../data/models/order_model.dart';
import '../../../providers/base_provider.dart';
import '../../../core/utils/image_helper.dart';

class OrderDetailScreen extends StatelessWidget {
  final OrderModel order;

  /// Hàm khởi tạo màn hình chi tiết đơn hàng.
  /// Tham số đầu vào: [order] chứa toàn bộ thông tin về đơn hàng cần hiển thị.
  const OrderDetailScreen({super.key, required this.order});

  /// Bộ định dạng tiền tệ dùng chung cho toàn màn hình, được khai báo tĩnh để tối ưu bộ nhớ.
  static final currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    /// Lấy các thông tin cấu hình giao diện và người dùng từ BaseProvider.
    final base = context.watch<BaseProvider>();
    final isDark = base.isDarkMode;
    final double px = base.textOffset;

    return Scaffold(
      appBar: AppBar(title: const Text("CHI TIẾT ĐƠN HÀNG", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Hiển thị các thông tin cơ bản của đơn hàng như mã và trạng thái.
            _buildInfoTile(Icons.info_outline, "Mã đơn hàng", order.code, isDark),
            _buildInfoTile(Icons.delivery_dining_outlined, "Trạng thái", order.status.toUpperCase(), isDark, color: Colors.orange),

            const SizedBox(height: 24),
            const Text("DANH SÁCH SẢN PHẨM", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12)),
            const Divider(),

            /// Duyệt qua danh sách sản phẩm (items) có trong đơn hàng để hiển thị.
            ...order.items.map((item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ImageHelper.load(item.phone?.thumbnail, width: 50, height: 50, borderRadius: 8),
              title: Text(item.phone?.title ?? "", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14 + px)),
              subtitle: Text("Số lượng: ${item.quantity}", style: TextStyle(fontSize: 12 + px)),
              trailing: Text(currency.format(item.price), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px)),
            )),

            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("TỔNG THANH TOÁN", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(currency.format(order.totalAmount), style: const TextStyle(fontSize: 20, color: Colors.redAccent, fontWeight: FontWeight.bold)),
              ],
            ),

            const SizedBox(height: 40),

            /// Chỉ hiển thị nút hủy đơn nếu trạng thái đơn hàng đang là 'pending' (chờ xử lý).
            if (order.status == 'pending')
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () => _handleCancel(context, base),
                child: const Text("HỦY ĐƠN HÀNG NÀY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Xây dựng một hàng hiển thị thông tin đơn lẻ kèm biểu tượng.
  /// Tham số đầu vào: [icon], [label] (nhãn), [value] (giá trị), [isDark], [color] (màu sắc tùy chọn).
  /// Giá trị trả về: Widget dạng hàng (Row).
  Widget _buildInfoTile(IconData icon, String label, String value, bool isDark, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color ?? Colors.blueAccent),
          const SizedBox(width: 12),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  /// Chức năng: Hiển thị hộp thoại xác nhận và thực hiện logic hủy đơn hàng qua API.
  /// Tham số đầu vào: [context], [base] (Provider chứa ApiService và Token).
  /// Giá trị trả về: Không có (Sử dụng async/await xử lý kết quả).
  void _handleCancel(BuildContext context, BaseProvider base) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận hủy đơn?"),
        content: const Text("Hệ thống sẽ tự động cộng lại số lượng máy vào kho của Shop."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Đóng")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              /// Gọi API hủy đơn hàng bằng token xác thực và ID đơn hàng.
              final res = await base.apiService.cancelOrder(base.token!, order.id);

              /// Kiểm tra Widget còn tồn tại hay không trước khi thực hiện điều hướng để tránh lỗi.
              if (!ctx.mounted) return;

              if (res['success']) {
                Fluttertoast.showToast(msg: "Đã hủy đơn thành công!");
                Navigator.pop(ctx);

                /// Quay lại màn hình trước và gửi tín hiệu báo hiệu cần tải lại dữ liệu.
                if (!context.mounted) return;
                Navigator.pop(context, true);
              } else {
                /// Hiển thị thông báo lỗi từ máy chủ nếu hủy đơn thất bại.
                Fluttertoast.showToast(msg: res['message'] ?? "Lỗi hủy đơn");
              }
            },
            child: const Text("Hủy đơn", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}