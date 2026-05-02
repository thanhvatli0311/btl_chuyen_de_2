import 'package:flutter/material.dart';
import '../data/models/revenue_transaction_model.dart';
import '../data/models/shop_revenue_stats.dart';
import '../data/repositories/api_service.dart';

class RevenueProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // 1. Trạng thái dữ liệu
  ShopRevenueStats? _stats;
  List<RevenueTransactionModel> _transactions = [];
  bool _isLoading = false;
  String? _error;

  // Getters để giao diện truy cập
  ShopRevenueStats? get stats => _stats;
  List<RevenueTransactionModel> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Hàm lấy dữ liệu doanh thu tổng quát (Thẻ thống kê + Biểu đồ + Tăng trưởng)
  Future<void> fetchRevenueStats(String token, {String? start, String? end}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _apiService.getRevenueStats(token, start: start, end: end);
      debugPrint("JSON STATS TỪ SERVER: ${res.data}");

      if (res.statusCode == 200 && res.data['success'] == true) {
        // Dữ liệu stats thường không phân trang nên vẫn lấy res.data['data']
        _stats = ShopRevenueStats.fromJson(res.data['data']);
        _error = null;
      }
    } catch (e) {
      debugPrint("❌ Lỗi fetchRevenueStats: $e");
      _error = "Lỗi nạp thống kê: $e";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Hàm lấy lịch sử giao dịch dòng tiền (Xử lý phân trang Laravel)
  Future<void> fetchTransactions(String token) async {
    _setLoading(true);
    try {
      final res = await _apiService.getRevenueTransactions(token);
      if (res.statusCode == 200 && res.data['success'] == true) {
        // ✅ Vì Tâm dùng get() nên data trả về là một List trực tiếp
        final List rawList = res.data['data'] as List;

        _transactions = rawList.map((e) => RevenueTransactionModel.fromJson(e)).toList();
        _error = null;
      }
    } catch (e) {
      debugPrint("❌ Lỗi dòng tiền: $e");
      _error = "Lỗi nạp giao dịch: $e";
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearData() {
    _stats = null;
    _transactions = [];
    _error = null;
    notifyListeners();
  }
}