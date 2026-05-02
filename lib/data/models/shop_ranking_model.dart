class ShopRankingModel {
  final int id;
  final String name;
  final double revenue; // Tổng doanh thu (GMV)

  ShopRankingModel({required this.id, required this.name, required this.revenue});

  factory ShopRankingModel.fromJson(Map<String, dynamic> json) {
    return ShopRankingModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Cửa hàng không tên',
      // Lưu ý: Key 'revenue' phải khớp với alias trong AdminController::getShopRankings
      revenue: double.tryParse(json['revenue']?.toString() ?? '0') ?? 0.0,
    );
  }
}