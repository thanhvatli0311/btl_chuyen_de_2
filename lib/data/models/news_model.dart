import 'dart:convert';
import 'shop_model.dart';
import 'user_model.dart';
import 'phone_model.dart';

class NewsPostModel {
  final int id;
  final int shopId;
  final UserModel? user;
  final String title;
  final String content;
  final List<String> images;
  final DateTime createdAt;
  final ShopModel? shop;
  final List<NewsCommentModel> comments;
  final List<PhoneModel> linkedProducts;

  int likesCount;
  bool isLiked;
  int commentsCount;

  NewsPostModel({
    required this.id, required this.shopId, required this.title,
    required this.content, required this.images, required this.likesCount,
    this.isLiked = false, required this.commentsCount, required this.createdAt,
    this.shop, this.user, required this.comments, required this.linkedProducts,
  });

  String? get imageUrl => images.isNotEmpty ? images.first : null;

  factory NewsPostModel.fromJson(Map<String, dynamic> json) {
    // ✅ FIX: Xử lý mảng ảnh dù là String JSON hay List
    List<String> parsedImages = [];
    if (json['images'] != null) {
      if (json['images'] is String) {
        try { parsedImages = List<String>.from(jsonDecode(json['images'])); } catch (_) {}
      } else if (json['images'] is List) {
        parsedImages = List<String>.from(json['images']);
      }
    }

    return NewsPostModel(
      id: json['id'] ?? 0,
      shopId: json['shop_id'] ?? 0,
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      images: parsedImages,
      likesCount: int.tryParse(json['likes_count']?.toString() ?? '0') ?? 0,
      isLiked: json['is_liked'] == true || json['is_liked'] == 1,
      commentsCount: int.tryParse(json['comments_count']?.toString() ?? '0') ?? 0,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toString()),
      shop: json['shop'] != null ? ShopModel.fromJson(json['shop']) : null,
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      comments: (json['comments'] as List?)?.map((i) => NewsCommentModel.fromJson(i)).toList() ?? [],
      linkedProducts: (json['linked_products'] as List?)?.map((i) => PhoneModel.fromJson(i)).toList() ?? [],
    );
  }
}

class NewsCommentModel {
  final int id, postId, userId;
  final String content;
  final int? parentId;
  final DateTime createdAt;
  final UserModel? user;

  NewsCommentModel({
    required this.id, required this.postId, required this.userId,
    required this.content, this.parentId, required this.createdAt, this.user,
  });

  factory NewsCommentModel.fromJson(Map<String, dynamic> json) {
    return NewsCommentModel(
      id: json['id'] ?? 0,
      postId: json['post_id'] ?? 0,
      userId: json['user_id'] ?? 0,
      content: json['content']?.toString() ?? '',
      parentId: json['parent_id'],
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toString()),
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
    );
  }
}