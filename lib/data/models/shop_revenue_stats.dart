// 📂 file: lib/data/models/shop_revenue_stats.dart

class ShopRevenueStats {
  final double totalRevenue;
  final double currentBalance;
  final int totalOrders;
  final double growthRate; // ✅ Trường mới để so sánh tăng trưởng
  final List<RevenueChartData> chartData;

  ShopRevenueStats({
    required this.totalRevenue,
    required this.currentBalance,
    required this.totalOrders,
    required this.growthRate,
    required this.chartData,
  });

  factory ShopRevenueStats.fromJson(Map<String, dynamic> json) {
    return ShopRevenueStats(
      totalRevenue: double.tryParse(json['total_revenue'].toString()) ?? 0.0,
      currentBalance: double.tryParse(json['balance'].toString()) ?? 0.0,
      totalOrders: int.tryParse(json['total_orders'].toString()) ?? 0,
      // ✅ Bóc tách growth_rate từ API Laravel trả về
      growthRate: double.tryParse(json['growth_rate'].toString()) ?? 0.0,
      chartData: (json['chart_data'] as List? ?? [])
          .map((e) => RevenueChartData.fromJson(e))
          .toList(),
    );
  }
}

class RevenueChartData {
  final String date;
  final double revenue;

  RevenueChartData({required this.date, required this.revenue});

  factory RevenueChartData.fromJson(Map<String, dynamic> json) {
    return RevenueChartData(
      date: json['date'] ?? '',
      revenue: double.tryParse(json['revenue'].toString()) ?? 0.0,
    );
  }
}