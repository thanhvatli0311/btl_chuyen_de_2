import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../data/repositories/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<bool> login(String email, String password, dynamic baseProvider) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _apiService.login(email, password);

      if (res.data['success'] == true) {
        await baseProvider.handleLoginSuccess(
            res.data['access_token'].toString(),
            res.data['user']
        );
        return true;
      } else {
        // ✅ BÁO LỖI CHO NGƯỜI DÙNG: Hiển thị lý do từ Server (sai pass, mail không tồn tại...)
        Fluttertoast.showToast(msg: res.data['message'] ?? "Thông tin đăng nhập không chính xác!");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi kết nối máy chủ, vui lòng thử lại sau!");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  Future<bool> sendOtp(String email) async {
    try {
      final res = await _apiService.sendOtp(email);
      // ✅ res giờ là Response object nên phải dùng .data
      if (res.data['success'] == true) return true;

      Fluttertoast.showToast(msg: res.data['message'] ?? "Không thể gửi mã OTP!");
      return false;
    } catch (_) {
      Fluttertoast.showToast(msg: "Lỗi hệ thống khi gửi mã!");
      return false;
    }
  }
}