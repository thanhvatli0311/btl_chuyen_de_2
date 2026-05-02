import 'shop_model.dart';

class UserModel {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String? address;
  final String role;
  final String? avatar;
  final String status;
  final ShopModel? shop;
  // ✅ THÊM DÒNG NÀY: Để hỗ trợ hiển thị trạng thái online trong Chat
  final bool isOnline;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    this.address,
    required this.role,
    this.avatar,
    required this.status,
    this.shop,
    this.isOnline = false, // Mặc định là offline
  });

  // ✅ GETTER CHỐNG LỖI MÀN HÌNH ĐỎ (Hỗ trợ avatarUrl)
  String get avatarUrl => avatar ?? '';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      address: json['address'],
      role: json['role'] ?? 'customer',
      avatar: json['avatar'],
      status: json['status'] ?? 'active',
      shop: json['shop'] != null ? ShopModel.fromJson(json['shop']) : null,
      // ✅ BÓC TÁCH TRẠNG THÁI: Tương thích với key is_online từ Laravel
      isOnline: json['is_online'] == true || json['is_online'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'avatar': avatar,
      'status': status,
      'shop': shop?.toJson(),
      'is_online': isOnline,
    };
  }
}