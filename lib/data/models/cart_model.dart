import 'phone_model.dart';

class CartModel {
  final int id;
  final int userId;
  final int phoneId;
  final int quantity;
  final PhoneModel? phone;

  CartModel({
    required this.id,
    required this.userId,
    required this.phoneId,
    required this.quantity,
    this.phone,
  });

  factory CartModel.fromJson(Map<String, dynamic> json) {
    return CartModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      userId: int.tryParse(json['user_id'].toString()) ?? 0,
      phoneId: int.tryParse(json['phone_id'].toString()) ?? 0,
      quantity: int.tryParse(json['quantity'].toString()) ?? 1,
      phone: json['phone'] != null ? PhoneModel.fromJson(json['phone']) : null,
    );
  }
}