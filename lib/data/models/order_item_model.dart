import 'phone_model.dart';

class OrderItemModel {
  final int id;
  final int phoneId;
  final double price;
  final int quantity;
  final PhoneModel? phone; // Chứa thông tin máy (tên, ảnh) để hiển thị

  OrderItemModel({
    required this.id,
    required this.phoneId,
    required this.price,
    required this.quantity,
    this.phone,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'],
      phoneId: json['phone_id'],
      // Ép kiểu decimal từ SQL (chuỗi) sang double trong Flutter
      price: double.parse(json['price'].toString()),
      quantity: json['quantity'],
      // Nếu Laravel có eager load 'phone', chúng ta nạp vào luôn
      phone: json['phone'] != null ? PhoneModel.fromJson(json['phone']) : null,
    );
  }
}