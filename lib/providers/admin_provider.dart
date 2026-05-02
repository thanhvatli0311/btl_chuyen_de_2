import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/models/admin_stats_model.dart';
import '../data/models/daily_revenue_model.dart';
import '../data/models/revenue_transaction_model.dart';
import '../data/models/shop_model.dart';
import '../data/models/shop_ranking_model.dart' show ShopRankingModel;
import '../data/models/system_setting_model.dart';

import '../data/models/user_model.dart';
import '../data/repositories/api_service.dart';

class AdminProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  AdminDashboardStats? _stats;
  List<SystemSettingModel> _settings = [];

  List<DailyRevenueModel> _dailyRevenue = [];
  List<ShopRankingModel> _shopRankings = [];
  List<ShopModel> _shops = [];
  List<DailyRevenueModel> _selectedShopChart = [];
  List<RevenueTransactionModel> _selectedShopTx = [];
  List<UserModel> _users = [];
  List<UserModel> get users => _users;


  bool _isLoading = false;
  String? _error;

  // Getters
  AdminDashboardStats? get stats => _stats;
  List<SystemSettingModel> get settings => _settings;

  List<dynamic> get dailyRevenue => _dailyRevenue;
  List<dynamic> get shopRankings => _shopRankings;
  List<ShopModel> get shops => _shops;
  List<DailyRevenueModel> get selectedShopChart => _selectedShopChart;
  List<RevenueTransactionModel> get selectedShopTx => _selectedShopTx;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime endDate = DateTime.now();

  // ✅ HÀM BỔ TRỢ: Dùng chung cho toàn bộ class để code ngắn gọn hơn
  void _setLoading(bool value) {
    _isLoading = value;
    _error = null; // Reset lỗi mỗi khi bắt đầu load mới
    notifyListeners();
  }

  /// 1. Lấy số liệu thống kê tổng sàn
  Future<void> fetchDashboardStats(String token) async {
    _setLoading(true); // Thay thế cách viết thủ công cũ
    try {
      final res = await _apiService.getAdminDashboardStats(token);
      if (res.statusCode == 200 && res.data['success'] == true) {
        _stats = AdminDashboardStats.fromJson(res.data['data']);
        debugPrint("✅ Admin Stats Loaded: ${_stats?.totalPlatformRevenue}");
      } else {
        _error = res.data['message'] ?? "Không thể lấy dữ liệu thống kê";
      }
    } catch (e) {
      _error = "Lỗi kết nối Server: $e";
    } finally {
      _setLoading(false);
    }
  }

  /// 2. Lấy toàn bộ cấu hình sàn (Phí sàn, Tiền cọc)
  Future<void> fetchSystemSettings(String token) async {
    try {
      final res = await _apiService.getSystemSettings(token);
      if (res.statusCode == 200 && res.data['success'] == true) {
        final List list = res.data['data'];
        _settings = list.map((e) => SystemSettingModel.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Lỗi nạp cấu hình: $e");
    }
  }

  /// 3. Cập nhật cấu hình hệ thống
  Future<bool> updateSetting(String token, String key, String value) async {
    try {
      final res = await _apiService.updateSystemSetting(token, key, value);
      if (res.statusCode == 200 && res.data['success'] == true) {
        await fetchSystemSettings(token);
        return true;
      }
    } catch (e) {
      debugPrint("Lỗi cập nhật cấu hình: $e");
    }
    return false;
  }



  /// 5. Lấy danh sách Shop theo trạng thái (Duyệt Shop)
  Future<void> fetchAdminShops(String token, String status) async {
    _setLoading(true);
    try {
      final res = await _apiService.getAdminShops(token, status: status);
      if (res.statusCode == 200 && res.data['success'] == true) {
        final List list = res.data['data'];
        _shops = list.map((e) => ShopModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Lỗi nạp shop: $e");
    } finally {
      _setLoading(false);
    }
  }

  /// 6. Thay đổi trạng thái Shop (Chấp nhận/Từ chối)
  Future<bool> changeShopStatus(String token, int shopId, String status) async {
    try {
      final res = await _apiService.updateShopStatus(token, shopId, status);
      if (res.statusCode == 200 && res.data['success'] == true) {
        _shops.removeWhere((s) => s.id == shopId);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Lỗi cập nhật: $e");
    }
    return false;
  }

  /// Chức năng: Thực hiện lệnh phát thông báo nội bộ tới toàn bộ người dùng hệ thống.
  /// Tham số đầu vào: [token] mã xác thực, [title] tiêu đề, [content] nội dung tin.
  /// Giá trị trả về: Future<bool> xác định việc gửi tin thành công hay thất bại.
  Future<bool> sendBroadcast({
    required String token,
    required String title,
    required String message,
  }) async {
    try {
      /// CHỈNH SỬA: Gọi đúng hàm sendAdminBroadcast với tham số có tên (Named Parameters)
      final res = await _apiService.sendAdminBroadcast(
        token: token,
        title: title,
        message: message,
      );

      if (res.data['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Lỗi AdminProvider - sendBroadcast: $e");
      return false;
    }
  }
  Future<void> fetchDetailedStats(String token) async {
    _setLoading(true);
    try {
      final res1 = await _apiService.getAdminDailyRevenue(token);
      final res2 = await _apiService.getAdminShopRankings(token);

      if (res1.data['success'] == true) {
        final List raw1 = res1.data['data'];
        _dailyRevenue = raw1.map((e) => DailyRevenueModel.fromJson(e)).toList();
      }

      if (res2.data['success'] == true) {
        final List raw2 = res2.data['data'];
        _shopRankings = raw2.map((e) => ShopRankingModel.fromJson(e)).toList();
      }
      notifyListeners();
    } catch (e) {
      debugPrint("❌ Lỗi nạp chi tiết: $e");
    } finally {
      _setLoading(false);
    }
  }
  // Hàm nạp thống kê có kèm lọc ngày
  Future<void> fetchAdminRevenueAnalytics(String token) async {
    _setLoading(true);
    try {
      String startStr = DateFormat('yyyy-MM-dd').format(startDate);
      String endStr = DateFormat('yyyy-MM-dd').format(endDate);

      // Gọi API
      final res1 = await _apiService.getAdminDailyRevenue(token, start: startStr, end: endStr);
      final res2 = await _apiService.getAdminShopRankings(token);

      // ✅ FIX LỖI 1: Kiểm tra an toàn để tránh lỗi 'Null' is not bool
      if (res1.data != null && res1.data['success'] == true) {
        final List rawList = res1.data['data'] as List;
        // ✅ FIX LỖI 2: Ép kiểu từ dynamic sang Model cụ thể
        _dailyRevenue = rawList.map((e) => DailyRevenueModel.fromJson(e)).toList();
      }

      if (res2.data != null && res2.data['success'] == true) {
        final List rawRankings = res2.data['data'] as List;
        _shopRankings = rawRankings.map((e) => ShopRankingModel.fromJson(e)).toList();
      }

      notifyListeners();
    } catch (e) {
      debugPrint("❌ Lỗi nạp Analytics: $e");
    } finally {
      _setLoading(false);
    }
  }
  Future<void> fetchShopDetailAnalytics(String token, int shopId, String start, String end) async {
    _setLoading(true);
    try {
      final res = await _apiService.getAdminShopDetailAnalytics(token, shopId, start, end);
      if (res.data['success']) {
        final List rawChart = res.data['data']['chart'];
        final List rawTx = res.data['data']['transactions'];

        _selectedShopChart = rawChart.map((e) => DailyRevenueModel.fromJson(e)).toList();
        _selectedShopTx = rawTx.map((e) => RevenueTransactionModel.fromJson(e)).toList();
        notifyListeners();
      }
    } finally {
      _setLoading(false);
    }
  }
  Future<void> fetchAllUsers(String token) async {
    _setLoading(true);
    try {
      final res = await _apiService.getAdminUsers(token);
      if (res.data['success'] == true) {
        final List list = res.data['data'];
        _users = list.map((e) => UserModel.fromJson(e)).toList();
        notifyListeners();
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateUserAccount(String token, int id, {String? role, String? status}) async {
    try {
      final res = await _apiService.updateUserStatus(token, id, role: role, status: status);
      return res.data['success'] == true;
    } catch (e) {
      return false;
    }
  }
}