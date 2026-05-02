import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../data/models/phone_model.dart';
import '../data/repositories/api_service.dart';

class ShopProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<PhoneModel> _inventory = [];
  bool _isLoading = false;

  List<PhoneModel> get inventory => _inventory;
  bool get isLoading => _isLoading;

  Future<void> fetchInventory(String token) async {
    _isLoading = true;
    notifyListeners();
    // Đồng bộ hàm lấy máy
    _inventory = await _apiService.getMyShopPhones(token);
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> deletePhone(int id, String token) async {
    try {
      final res = await _apiService.deletePhone(id, token);
      // Kiểm tra success từ JSON trả về thay vì statusCode 200
      if (res.data['success'] == true) {
        _inventory.removeWhere((p) => p.id == id);
        notifyListeners();
        Fluttertoast.showToast(msg: "Đã xóa máy khỏi kho");
        return true;
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi xóa sản phẩm");
    }
    return false;
  }
}