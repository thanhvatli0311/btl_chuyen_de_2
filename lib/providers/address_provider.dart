import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:dio/dio.dart';
import '../data/models/address_model.dart';
import '../data/repositories/api_service.dart';

class AddressProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<AddressModel> _addresses = [];
  bool _isLoading = false;

  List<AddressModel> get addresses => _addresses;
  bool get isLoading => _isLoading;

  // ✅ 1. Lấy danh sách địa chỉ (Tự động sắp xếp mặc định lên đầu)
  Future<void> fetchAddresses(String token) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _apiService.getAddresses(token);
      // API trả về data là List các AddressModel
      _addresses = res;
    } catch (e) {
      debugPrint("❌ Lỗi nạp địa chỉ: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ 2. Thêm địa chỉ mới
  Future<bool> addAddress(String token, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    try {
      // Data gồm: recipient_name, phone, province, district, ward, detail...
      final res = await _apiService.storeAddress(token, data);
      if (res.data['success'] == true) {
        Fluttertoast.showToast(msg: "Thêm địa chỉ thành công!");
        await fetchAddresses(token); // Tải lại để cập nhật danh sách local
        return true;
      }
    } on DioException catch (e) {
      _handleError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  // ✅ 3. Xóa địa chỉ (Chặn xóa địa chỉ mặc định)
  Future<bool> removeAddress(String token, int id) async {
    try {
      // Tìm địa chỉ định xóa để kiểm tra
      final target = _addresses.firstWhere((a) => a.id == id);
      if (target.isDefault) {
        Fluttertoast.showToast(msg: "Không được xóa địa chỉ mặc định!", backgroundColor: Colors.orange);
        return false;
      }

      final res = await _apiService.deleteAddress(token, id);
      if (res.data['success'] == true) {
        _addresses.removeWhere((a) => a.id == id);
        notifyListeners();
        Fluttertoast.showToast(msg: "Đã xóa địa chỉ.");
        return true;
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi: Không thể xóa địa chỉ này.");
    }
    return false;
  }

  // ✅ 4. Lấy địa chỉ mặc định (Dùng cho màn hình Checkout)
  AddressModel? getDefaultAddress() {
    try {
      return _addresses.firstWhere((a) => a.isDefault == true);
    } catch (_) {
      return _addresses.isNotEmpty ? _addresses.first : null;
    }
  }

  // Helper bóc tách lỗi chi tiết từ Server
  void _handleError(DioException e) {
    String msg = "Lỗi kết nối!";
    if (e.response?.data != null) {
      final data = e.response?.data;
      msg = (data is Map && data['errors'] != null)
          ? data['errors'].values.first[0].toString()
          : (data['message'] ?? "Lỗi hệ thống");
    }
    Fluttertoast.showToast(msg: msg, backgroundColor: Colors.red);
  }
  Future<bool> updateAddress(String token, int id, Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    try {
      // Gọi API PUT /customer/addresses/{id}
      final res = await _apiService.updateAddress(token, id, data);
      if (res.data['success'] == true) {
        Fluttertoast.showToast(msg: "Cập nhật địa chỉ thành công!");
        await fetchAddresses(token); // Tải lại danh sách
        return true;
      }
    } catch (e) {
      debugPrint("❌ Lỗi updateAddress: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }
}