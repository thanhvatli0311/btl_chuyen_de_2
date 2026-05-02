class ShopModel {
  final int id;
  final int userId;
  final String name;
  final String slug;
  final String? description;
  final String? avatar;
  final String warehouseAddress;
  final double balance; // Phải là double để khớp với tiền ví 1.000.000đ
  final String status;

  ShopModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.slug,
    this.description,
    this.avatar,
    required this.warehouseAddress,
    required this.balance,
    required this.status,
  });

  factory ShopModel.fromJson(Map<String, dynamic> json) {
    return ShopModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      avatar: json['avatar'],
      warehouseAddress: json['warehouse_address'] ?? 'Chưa cập nhật',
      // Ép kiểu num sang double để tránh lỗi "String is not a subtype of double"
      balance: (json['balance'] is String)
          ? double.parse(json['balance'])
          : (json['balance'] ?? 0.0).toDouble(),
      status: json['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id, 'user_id': userId, 'name': name, 'slug': slug,
    'description': description, 'avatar': avatar,
    'warehouse_address': warehouseAddress, 'balance': balance, 'status': status,
  };
}