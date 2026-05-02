import 'address_model.dart';
import 'order_item_model.dart';
import 'shop_model.dart';

class OrderModel {
  final int id;
  final String code;
  final String status;
  final double totalAmount;
  final String paymentMethod;
  final DateTime createdAt;
  final ShopModel? shop;
  final List<OrderItemModel> items;
  final AddressModel? address;

  OrderModel({
    required this.id,
    required this.code,
    required this.status,
    required this.totalAmount,
    required this.paymentMethod,
    required this.createdAt,
    required this.shop,
    required this.items,
    this.address,
  });

  // Hàm chuyển đổi từ JSON (Laravel) sang Object (Flutter)
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      code: json['code'],
      status: json['status'],
      totalAmount: double.tryParse(json['total_amount']?.toString() ?? '0') ?? 0.0,
      paymentMethod: json['payment_method'],
      createdAt: DateTime.parse(json['created_at']),
      shop: json['shop'] != null ? ShopModel.fromJson(json['shop']) : null,
      items: json['items'] != null ? (json['items'] as List).map((e) => OrderItemModel.fromJson(e)).toList() : [],
      address: json['address'] != null ? AddressModel.fromJson(json['address']) : null,
    );
  }
}