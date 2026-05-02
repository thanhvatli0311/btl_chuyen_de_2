import 'package:flutter/material.dart';
import '../data/repositories/api_service.dart';
import '../data/models/order_model.dart';

class ShopOrderProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<OrderModel> _orders = [];
  bool _isLoading = false;

  List<OrderModel> get orders => _orders;
  bool get isLoading => _isLoading;

  // Lấy danh sách đơn hàng
  Future<void> fetchOrders(String token) async {
    _isLoading = true;
    _orders = [];
    notifyListeners();
    try {
      final res = await _apiService.getShopOrders(token);
      if (res.statusCode == 200 && res.data['success'] == true) {
        var list = res.data['data'] as List;
        _orders = list.map((item) => OrderModel.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint("❌ Lỗi load đơn hàng: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cập nhật trạng thái (Duyệt, Giao hàng, Hủy)
  Future<bool> changeStatus(int orderId, String status, String token, dynamic baseProvider) async {
    final res = await _apiService.updateOrderStatus(orderId: orderId, status: status, token: token);

    if (res.statusCode == 200) {
      // 1. Tải lại danh sách đơn hàng để cập nhật Tab
      await fetchOrders(token);

      // 2. 🔥 QUAN TRỌNG: Nạp lại Profile để ví nhảy số ngay lập tức
      if (baseProvider != null) {
        await baseProvider.getProfile();
      }

      return true;
    }
    return false;
  }
}