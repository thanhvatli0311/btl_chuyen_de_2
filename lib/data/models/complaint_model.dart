import 'user_model.dart';
import 'order_model.dart';
import 'shop_model.dart';

class ComplaintModel {
  final int id;
  final int userId;
  final int orderId;
  final int shopId;
  final String type;
  final String description;
  final String status;
  final String? adminReply;
  final DateTime createdAt;
  final UserModel? user;
  final OrderModel? order;
  final ShopModel? shop;

  ComplaintModel({
    required this.id,
    required this.userId,
    required this.orderId,
    required this.shopId,
    required this.type,
    required this.description,
    required this.status,
    this.adminReply,
    required this.createdAt,
    this.user,
    this.order,
    this.shop,
  });

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      orderId: json['order_id'] ?? 0,
      shopId: json['shop_id'] ?? 0,
      type: json['type'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'pending',
      adminReply: json['admin_reply'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toString()),
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      order: json['order'] != null ? OrderModel.fromJson(json['order']) : null,
      shop: json['shop'] != null ? ShopModel.fromJson(json['shop']) : null,
    );
  }

  String get typeLabel {
    switch (type) {
      case 'cancel': return "Yêu cầu hủy đơn";
      case 'exchange': return "Yêu cầu đổi máy";
      case 'return': return "Yêu cầu trả hàng";
      case 'quality': return "Chất lượng không đúng";
      default: return "Khác";
    }
  }
}