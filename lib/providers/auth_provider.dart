import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../data/repositories/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Chức năng: Gọi API đăng nhập và cập nhật thông tin người dùng vào hệ thống.
  Future<bool> login(String email, String password, dynamic baseProvider) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _apiService.login(email, password);
      final isSuccess = res.data['success'] == true || res.data['success'].toString() == 'true';

      if (res.statusCode == 200 && isSuccess) {
        await baseProvider.handleLoginSuccess(
            res.data['access_token'].toString(),
            res.data['user']
        );
        return true;
      } else {
        Fluttertoast.showToast(msg: res.data['message'] ?? "Đăng nhập thất bại!");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi kết nối máy chủ!");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
  }

  /// Chức năng: Gửi yêu cầu mã OTP khôi phục mật khẩu.
  Future<bool> sendOtp(String email) async {
    try {
      final res = await _apiService.sendOtp(email);
      final isSuccess = res.data['success'] == true || res.data['success'].toString() == 'true';

      if (isSuccess) return true;
      Fluttertoast.showToast(msg: res.data['message'] ?? "Không thể gửi mã!");
      return false;
    } catch (_) {
      Fluttertoast.showToast(msg: "Lỗi hệ thống!");
      return false;
    }
  }
}