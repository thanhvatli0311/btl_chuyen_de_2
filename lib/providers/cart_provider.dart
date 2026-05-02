import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../data/models/phone_model.dart';
import '../data/repositories/api_service.dart';
import 'dart:async';

class CartItem {
  final int id; // cart_id từ SQL
  final PhoneModel phone;
  int quantity;
  bool isSelected;

  CartItem({
    required this.id,
    required this.phone,
    this.quantity = 1,
    this.isSelected = true
  });
}

class CartProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<CartItem> _items = [];
  bool _isLoading = false;
  String? _lastErrorMessage;
  Timer? _debounce;

  List<CartItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get lastErrorMessage => _lastErrorMessage;

  // 1. Lấy danh sách từ Server
  Future<void> fetchCart(String token) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _apiService.getCart(token);

      // ✅ DEBUG: Bật dòng này để xem dữ liệu thực tế nhận được là gì
      debugPrint("🛒 Dữ liệu trả về từ API: ${res.data}");

      if (res.statusCode == 200) {
        // Kiểm tra xem Laravel trả về mảng ở đâu (thường là res.data['data'])
        final dynamic responseData = res.data['data'];

        if (responseData is List) {
          _items = responseData.map((json) {
            // ✅ Fix logic nạp PhoneModel
            return CartItem(
              id: int.tryParse(json['id'].toString()) ?? 0,
              phone: PhoneModel.fromJson(json['phone']),
              quantity: int.tryParse(json['quantity'].toString()) ?? 1,
            );
          }).toList();

          debugPrint("✅ Đã nạp ${_items.length} món vào danh sách local");
        }
      }
    } catch (e) {
      debugPrint("❌ Lỗi chí mạng khi tải giỏ hàng: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  // 2. Thêm vào giỏ
  Future<String?> addToCart(PhoneModel phone, String token) async {
    try {
      final response = await _apiService.addToCart(
          phoneId: phone.id,
          quantity: 1,
          token: token
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        await fetchCart(token);
        return null; // Trả về null nghĩa là không có lỗi
      } else {
        // Trả về câu thông báo từ Backend (ví dụ: "Hết hàng")
        return response.data['message'] ?? "Không thể thêm vào giỏ";
      }
    } catch (e) {
      return "Lỗi kết nối máy chủ";
    }
  }

  // ✅ 3. CẬP NHẬT SỐ LƯỢNG (MỚI - Fix lỗi updateQuantity)
  void updateQuantityWithDebounce(int cartId, int newQuantity, String token) {
    // 1. Cập nhật giao diện ngay lập tức (Optimistic Update)
    int index = _items.indexWhere((item) => item.id == cartId);
    if (index == -1) return;

    _items[index].quantity = newQuantity;
    notifyListeners();

    // 2. Hủy bộ đếm cũ nếu khách vẫn đang nhấn liên tục
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // 3. Thiết lập bộ đếm mới (Đợi 500ms sau khi khách dừng bấm mới gọi API)
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final response = await _apiService.updateCartQuantity(cartId, newQuantity, token);

        if (response.statusCode != 200) {
          // Nếu Backend báo lỗi (ví dụ vượt quá tồn kho), nạp lại giỏ hàng chuẩn
          fetchCart(token);
          Fluttertoast.showToast(msg: response.data['message'] ?? "Lỗi cập nhật");
        }
      } catch (e) {
        debugPrint("❌ Lỗi Debounce API: $e");
      }
    });
  }
  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  // ✅ 4. XÓA MÓN HÀNG (MỚI - Fix lỗi removeItem)
  Future<void> removeItem(int cartId, String token) async {
    try {
      // Gọi API DELETE /api/cart/{id} của Laravel
      final response = await _apiService.removeFromCart(cartId, token);

      if (response.statusCode == 200) {
        // Xóa khỏi danh sách local và thông báo giao diện vẽ lại
        _items.removeWhere((item) => item.id == cartId);
        notifyListeners();
      }
    } catch (e) {
      debugPrint("❌ Lỗi xóa món hàng: $e");
    }
  }

  // 5. Chọn/Bỏ chọn sản phẩm
  void toggleSelection(int index) {
    if (index >= 0 && index < _items.length) {
      _items[index].isSelected = !_items[index].isSelected;
      notifyListeners();
    }
  }

  // 6. Tính tổng tiền các món ĐÃ CHỌN
  double get totalSelectedAmount {
    double total = 0;
    for (var item in _items) {
      if (item.isSelected) {
        double price = item.phone.discountPrice ?? item.phone.price;
        total += price * item.quantity;
      }
    }
    return total;
  }
// ✅ Sửa lại để nhận đúng 2 đối số: token và data
// 📂 file: cart_provider.dart

  Future<bool> processCheckout(String token, Map<String, dynamic> data) async {
    _isLoading = true;
    _lastErrorMessage = null; // Reset lỗi cũ trước khi gọi API
    notifyListeners();

    try {
      final res = await _apiService.checkout(token: token, data: data);

      if (res.statusCode == 200 || res.statusCode == 201) {
        List<int> orderedIds = List<int>.from(data['cart_ids']);
        _items.removeWhere((item) => orderedIds.contains(item.id));
        notifyListeners();
        return true;
      } else {
        // ✅ 3. Lưu thông báo lỗi từ Server (ví dụ: "Sản phẩm hết hàng") vào biến
        _lastErrorMessage = res.data['message'] ?? "Đặt hàng thất bại";
        return false;
      }
    } catch (e) {
      _lastErrorMessage = "Lỗi kết nối máy chủ";
      debugPrint("❌ Lỗi: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
