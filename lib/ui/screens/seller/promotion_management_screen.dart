import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../data/models/phone_model.dart';
import '../../../providers/base_provider.dart';
import '../../../core/utils/image_helper.dart';

class PromotionManagementScreen extends StatefulWidget {
  const PromotionManagementScreen({super.key});

  @override
  State<PromotionManagementScreen> createState() => _PromotionManagementScreenState();
}

class _PromotionManagementScreenState extends State<PromotionManagementScreen> {
  List<PhoneModel> _myPhones = [];
  bool _isLoading = true;

  /// Bộ định dạng tiền tệ Việt Nam dùng chung.
  static final NumberFormat _currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMyInventory());
  }

  /// Chức năng: Tải danh sách sản phẩm thuộc sở hữu của Shop.
  Future<void> _loadMyInventory() async {
    try {
      final base = context.read<BaseProvider>();
      final shopId = base.user?.shop?.id;
      final data = await base.apiService.getPhones();

      if (mounted) {
        setState(() {
          _myPhones = data.where((p) => p.shopId == shopId).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);
    final px = context.select<BaseProvider, double>((p) => p.textOffset);
    final token = context.select<BaseProvider, String?>((p) => p.token);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("QUẢN LÝ KHUYẾN MÃI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 + px)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).cardColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadMyInventory,
        child: _myPhones.isEmpty
            ? Center(child: Text("Chưa có sản phẩm để giảm giá.", style: TextStyle(fontSize: 14 + px, color: Colors.grey)))
            : ListView.builder(
          cacheExtent: 500,
          padding: const EdgeInsets.all(16),
          itemCount: _myPhones.length,
          itemBuilder: (ctx, i) => _buildPromotionCard(_myPhones[i], px, isDark, token ?? ""),
        ),
      ),
    );
  }

  /// Chức năng: Tạo thẻ sản phẩm.
  Widget _buildPromotionCard(PhoneModel p, double px, bool isDark, String token) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ImageHelper.load(p.thumbnailUrl, width: 75, height: 75, fit: BoxFit.cover),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text("Gốc: ${_currency.format(p.price)}", style: const TextStyle(color: Colors.grey, fontSize: 12), maxLines: 1),
                if (p.discountPrice != null)
                  Text("Giảm còn: ${_currency.format(p.discountPrice)}", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0047AB), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 12), elevation: 0),
            onPressed: () => _showDiscountDialog(p, token),
            child: Text(p.discountPrice == null ? "Giảm giá" : "Sửa", style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Chức năng: Hiển thị hộp thoại nhập giá (Đã fix lỗi Framework Assertion).
  void _showDiscountDialog(PhoneModel p, String token) {
    // Khai báo controller ở đây nhưng không dispose ở .then() nữa
    final controller = TextEditingController(text: p.discountPrice?.toInt().toString() ?? "");

    showDialog(
      context: context,
      barrierDismissible: false, // Tránh bấm ra ngoài gây lỗi dọn dẹp controller
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Giảm giá: ${p.title}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), maxLines: 1, overflow: TextOverflow.ellipsis),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Nhập giá mới hoặc để trống để gỡ giảm giá.", style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: "Giá khuyến mãi (đ)",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actionsOverflowButtonSpacing: 8,
        actions: [
          if (p.discountPrice != null)
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _updateDiscountLogic(p, null, token);
              },
              child: const Text("GỠ GIẢM GIÁ", style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () {
              final double? newPrice = double.tryParse(controller.text);
              if (newPrice != null && newPrice >= p.price) {
                Fluttertoast.showToast(msg: "Giá giảm phải nhỏ hơn giá gốc!");
                return;
              }
              Navigator.pop(ctx);
              _updateDiscountLogic(p, newPrice, token);
            },
            child: const Text("Xác nhận"),
          ),
        ],
      ),
    ).then((_) {
      // Delay một chút trước khi dispose để animation đóng dialog chạy xong hoàn toàn

      Future.delayed(const Duration(milliseconds: 200), () => controller.dispose());
    });
  }

  /// Chức năng: Gửi yêu cầu cập nhật giá khuyến mãi.
  Future<void> _updateDiscountLogic(PhoneModel p, double? newPrice, String token) async {
    try {
      final base = context.read<BaseProvider>();
      final res = await base.apiService.updatePhoneDiscount(p.id, newPrice, token);

      if (res.data['success'] == true) {
        Fluttertoast.showToast(msg: newPrice == null ? "Đã gỡ khuyến mãi!" : "Cập nhật thành công!");
        // Chỉ gọi load lại nếu màn hình vẫn còn tồn tại
        if (mounted) _loadMyInventory();
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi kết nối server!");
    }
  }
}