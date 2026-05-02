class AdminDashboardStats {
  final double totalShopRevenue;
  final double totalPlatformRevenue;
  final int activeShops;
  final int totalUsers;
  final int pendingWithdraws;

  AdminDashboardStats({
    required this.totalShopRevenue,
    required this.totalPlatformRevenue,
    required this.activeShops,
    required this.totalUsers,
    required this.pendingWithdraws,
  });

  factory AdminDashboardStats.fromJson(Map<String, dynamic> json) {
    return AdminDashboardStats(
      totalShopRevenue: double.tryParse(json['total_shop_revenue']?.toString() ?? '0') ?? 0.0,
      totalPlatformRevenue: double.tryParse(json['total_platform_revenue'].toString()) ?? 0.0,
      activeShops: int.tryParse(json['active_shops'].toString()) ?? 0,
      totalUsers: int.tryParse(json['total_users'].toString()) ?? 0,
      pendingWithdraws: int.tryParse(json['pending_withdraws'].toString()) ?? 0,
    );
  }
}