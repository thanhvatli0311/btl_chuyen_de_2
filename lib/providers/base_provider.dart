import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/models/user_model.dart';
import '../data/repositories/api_service.dart';
import '../core/utils/app_theme.dart';

class BaseProvider extends ChangeNotifier {
  // 1. Công cụ gọi API (Fix lỗi Getter ở HomeScreen)
  final ApiService _apiService = ApiService();
  ApiService get apiService => _apiService;

  // 2. Trạng thái người dùng
  String? _token;
  UserModel? _user;
  String? get token => _token;
  UserModel? get user => _user;

  // 3. Trạng thái Giao diện (Theme & Font size)
  bool _isDarkMode = false;
  double _textOffset = 0.0;
  bool get isDarkMode => _isDarkMode;
  double get textOffset => _textOffset;

  // Fix lỗi main.dart
  ThemeData get currentTheme {
    return _isDarkMode
        ? AppTheme.darkTheme(_textOffset)
        : AppTheme.lightTheme(_textOffset);
  }

  BaseProvider() {
    _loadInitialData();
  }

  /// Nạp dữ liệu từ bộ nhớ máy khi khởi động App
  Future<void> _loadInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
    _isDarkMode = prefs.getBool('is_dark_mode') ?? false;
    _textOffset = prefs.getDouble('text_offset') ?? 0.0;
    String? userJson = prefs.getString('user_data');
    if (userJson != null) { _user = UserModel.fromJson(jsonDecode(userJson)); }
    notifyListeners();
  }

  // ===========================================================================
  // 🛡️ HỆ THỐNG XÁC THỰC (FIXED: handleLoginSuccess)
  // ===========================================================================

  /// ✅ THÊM LẠI HÀM NÀY: Fix lỗi ở AuthScreen
  Future<void> handleLoginSuccess(String token, Map<String, dynamic> userData) async {
    _token = token;
    _user = UserModel.fromJson(userData);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    await prefs.setString('user_data', jsonEncode(userData));
    notifyListeners();
  }

  /// Nạp lại Profile từ SQL (Sửa key 'user' cho khớp Laravel)
  Future<void> getProfile() async {
    if (_token == null) return;
    try {
      final res = await _apiService.getProfile(_token!);
      if (res.data != null && res.data['success'] == true) {
        _user = UserModel.fromJson(res.data['user']);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_data', jsonEncode(res.data['user']));
        notifyListeners();
      }
    } catch (e) { debugPrint("❌ Sync Profile Error: $e"); }
  }

  // ===========================================================================
  // 🎨 CÀI ĐẶT GIAO DIỆN
  // ===========================================================================

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', _isDarkMode);
    notifyListeners();
  }

  Future<void> updateTextOffset(double offset) async {
    _textOffset = offset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('text_offset', offset);
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null; _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  // --- DEFINITION THEMES ---
  final _lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: const Color(0xFF0047AB),
    cardColor: Colors.white,
    scaffoldBackgroundColor: const Color(0xFFF4F7FA),
  );

  final _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFF0047AB),
    cardColor: const Color(0xFF1E1E1E),
    scaffoldBackgroundColor: const Color(0xFF121212),
  );

}