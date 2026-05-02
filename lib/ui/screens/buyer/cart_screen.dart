import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/base_provider.dart';
import '../../../core/utils/image_helper.dart';
import 'phone_detail_screen.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  /// Bộ định dạng tiền tệ dùng chung cho toàn màn hình.
  /// Khai báo static final để tránh việc khởi tạo lại đối tượng định dạng liên tục, giúp tiết kiệm bộ nhớ.
  static final NumberFormat _currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  /// Chức năng: Khởi tạo dữ liệu khi màn hình được đưa vào cây Widget.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  @override
  void initState() {
    super.initState();
    /// Sử dụng PostFrameCallback để nạp dữ liệu từ máy chủ ngay sau khi khung hình đầu tiên được dựng xong.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final base = context.read<BaseProvider>();
      if (base.token != null) {
        /// Gọi hàm lấy danh sách giỏ hàng thông qua CartProvider.
        context.read<CartProvider>().fetchCart(base.token!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    /// Lắng nghe các thay đổi về giao diện (Dark Mode) và kích thước chữ (px) từ BaseProvider.
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);
    final px = context.select<BaseProvider, double>((p) => p.textOffset);
    final token = context.select<BaseProvider, String?>((p) => p.token);

    /// Lấy số lượng sản phẩm trong giỏ hàng để cập nhật tiêu đề AppBar.
    final cartLength = context.select<CartProvider, int>((p) => p.items.length);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Text("Giỏ hàng ($cartLength)",
            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold, fontSize: 18 + px)),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProv, _) {
          /// Hiển thị vòng xoay tải dữ liệu nếu đang trong quá trình gọi API.
          if (cartProv.isLoading) return const Center(child: CircularProgressIndicator());
          /// Nếu danh sách trống, hiển thị màn hình thông báo giỏ hàng rỗng.
          if (cartProv.items.isEmpty) return _buildEmptyCart(isDark, px);

          return ListView.builder(
            /// Tạo vùng đệm 400 pixel bên ngoài màn hình để cuộn mượt mà hơn.
            cacheExtent: 400,
            padding: const EdgeInsets.all(16),
            itemCount: cartProv.items.length,
            itemBuilder: (context, index) {
              final item = cartProv.items[index];
              final phone = item.phone;
              /// Bỏ qua nếu dữ liệu sản phẩm bị lỗi hoặc bị xóa khỏi sàn.
              if (phone == null) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.02), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: InkWell(
                  /// Nhấn vào thẻ sản phẩm để xem chi tiết điện thoại.
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhoneDetailScreen(slug: phone.slug))),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        InkWell(
                          /// Xử lý chọn/bỏ chọn sản phẩm để thanh toán.
                          onTap: () => cartProv.toggleSelection(index),
                          child: Checkbox(
                            value: item.isSelected,
                            activeColor: const Color(0xFF0047AB),
                            onChanged: (val) => cartProv.toggleSelection(index),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ImageHelper.load(phone.thumbnailUrl, width: 70, height: 70, fit: BoxFit.cover),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(phone.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px)),
                              const SizedBox(height: 4),
                              /// Ưu tiên hiển thị giá khuyến mãi nếu có.
                              Text(_currency.format(phone.discountPrice ?? phone.price),
                                  style: TextStyle(color: const Color(0xFF0047AB), fontWeight: FontWeight.bold, fontSize: 13 + px)),
                              const SizedBox(height: 8),
                              /// Bộ điều khiển tăng giảm số lượng.
                              _buildQuantityController(cartProv, item, token!, px),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _confirmDelete(context, cartProv, item.id, token!),
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      /// Thanh tổng tiền và nút mua hàng ở phía dưới màn hình.
      bottomNavigationBar: Consumer<CartProvider>(
        builder: (context, cartProv, _) => _buildBottomCheckout(cartProv, isDark, px),
      ),
    );
  }

  /// Chức năng: Xây dựng bộ nút nhấn tăng/giảm số lượng sản phẩm.
  /// Tham số đầu vào: [cart] provider, [item] dữ liệu món hàng, [token] xác thực, [px] cỡ chữ.
  /// Giá trị trả về: Widget dạng hàng (Row) chứa các nút điều khiển.
  Widget _buildQuantityController(CartProvider cart, dynamic item, String token, double px) {
    final int currentQty = int.tryParse(item.quantity.toString()) ?? 1;

    return Row(
      children: [
        /// Nút giảm số lượng (tối thiểu là 1).
        _qtyBtn(Icons.remove, () {
          if (currentQty > 1) {
            /// Gọi hàm cập nhật có cơ chế Debounce để tránh spam API liên tục.
            cart.updateQuantityWithDebounce(item.id, currentQty - 1, token);
          }
        }),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text("$currentQty", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px)),
        ),
        /// Nút tăng số lượng.
        _qtyBtn(Icons.add, () => cart.updateQuantityWithDebounce(item.id, currentQty + 1, token)),
      ],
    );
  }

  /// Chức năng: Tạo giao diện nút nhấn tăng giảm số lượng đơn lẻ.
  /// Tham số đầu vào: [icon] biểu tượng, [onTap] hàm xử lý khi nhấn.
  /// Giá trị trả về: Widget nút nhấn có đường viền.
  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 16),
        ),
      ),
    );
  }

  /// Chức năng: Hiển thị giao diện khi giỏ hàng không có sản phẩm nào.
  /// Tham số đầu vào: [isDark] chế độ tối, [px] cỡ chữ.
  /// Giá trị trả về: Widget căn giữa chứa Icon và thông báo.
  Widget _buildEmptyCart(bool isDark, double px) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 100, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text("Giỏ hàng của bạn đang trống", style: TextStyle(color: Colors.grey.shade600, fontSize: 16 + px)),
        ],
      ),
    );
  }

  /// Chức năng: Xây dựng thanh thanh toán ở dưới cùng màn hình.
  /// Tham số đầu vào: [cart] provider, [isDark] chế độ tối, [px] cỡ chữ.
  /// Giá trị trả về: Widget chứa thông tin tổng tiền và nút mua hàng.
  Widget _buildBottomCheckout(CartProvider cart, bool isDark, double px) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Tổng thanh toán", style: TextStyle(fontSize: 12 + px, color: Colors.grey)),
                /// Tính toán tổng tiền dựa trên các sản phẩm đã được tích chọn.
                Text(_currency.format(cart.totalSelectedAmount),
                    style: TextStyle(fontSize: 18 + px, fontWeight: FontWeight.bold, color: const Color(0xFF0047AB))),
              ],
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0047AB),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              /// Chỉ cho phép nhấn mua hàng nếu tổng số tiền lớn hơn 0.
              onPressed: cart.totalSelectedAmount > 0 ? () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
              } : null,
              child: Text("MUA HÀNG", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15 + px)),
            ),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Hiển thị hộp thoại xác nhận trước khi xóa sản phẩm khỏi giỏ hàng.
  /// Tham số đầu vào: [context], [cart] provider, [cartId] mã giỏ hàng, [token] xác thực.
  /// Giá trị trả về: Không có (Mở một Dialog).
  void _confirmDelete(BuildContext context, CartProvider cart, int cartId, String token) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Xác nhận"),
        content: const Text("Bạn muốn xóa máy này khỏi giỏ hàng?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          TextButton(onPressed: () {
            /// Thực hiện xóa và đóng hộp thoại nếu Widget vẫn còn tồn tại.
            cart.removeItem(cartId, token);
            if (ctx.mounted) Navigator.pop(ctx);
          }, child: const Text("XÓA", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}