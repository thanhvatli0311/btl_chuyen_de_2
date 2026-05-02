// ✅ FILE: phone_model.dart - BẢN CHUẨN KHÔNG LỖI
import 'dart:convert';
import 'category_brand_model.dart';
import 'review_model.dart';
import '../../core/network/api_config.dart';
import 'shop_model.dart';

class PhoneSpecModel {
  final String key;
  final String value;

  PhoneSpecModel({required this.key, required this.value});

  factory PhoneSpecModel.fromJson(Map<String, dynamic> json) {
    return PhoneSpecModel(
      key: json['spec_key']?.toString() ?? '',
      value: json['spec_value']?.toString() ?? '',
    );
  }
}

class PhoneModel {
  final int id;
  final int shopId;
  final int brandId;
  final int categoryId;
  final String title;
  final String description;
  final String slug;
  final double price;
  final double? discountPrice;
  final int stock;
  final String condition;
  final String thumbnail;
  final List<String> images;
  final String status;
  final List<PhoneSpecModel> specs;
  final List<ReviewModel> reviews;
  final ShopModel? shop;
  final BrandModel? brand;


  PhoneModel({
    required this.id,
    required this.shopId,
    required this.brandId,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.slug,
    required this.price,
    this.discountPrice,
    required this.stock,
    required this.condition,
    required this.thumbnail,
    required this.images,
    required this.status,
    required this.specs,
    required this.reviews,
    this.shop,
    this.brand,
  });
  double get finalPrice => discountPrice ?? price;

  String get thumbnailUrl {
    if (thumbnail.isEmpty) return "https://via.placeholder.com/150";
    if (thumbnail.startsWith('http')) return thumbnail;
    String cleanBaseUrl = ApiConfig.baseUrl.replaceAll('/api', '');
    return "$cleanBaseUrl/storage/$thumbnail";
  }

  factory PhoneModel.fromJson(Map<String, dynamic> json) {
    // 1. Xử lý mảng ảnh (Hỗ trợ cả String JSON từ SQL và mảng từ API)
    List<String> imageList = [];
    var rawImages = json['images'];
    if (rawImages != null) {
      if (rawImages is String && rawImages.isNotEmpty) {
        try {
          var decoded = jsonDecode(rawImages);
          if (decoded is List) imageList = List<String>.from(decoded);
        } catch (_) {}
      } else if (rawImages is List) {
        imageList = List<String>.from(rawImages);
      }
    }

    return PhoneModel(
      id: json['id'] is int ? json['id'] : (int.tryParse(json['id']?.toString() ?? '0') ?? 0),
      shopId: json['shop_id'] is int ? json['shop_id'] : (int.tryParse(json['shop_id']?.toString() ?? '0') ?? 0),
      brandId: json['brand_id'] is int ? json['brand_id'] : (int.tryParse(json['brand_id']?.toString() ?? '0') ?? 0),
      categoryId: json['category_id'] is int ? json['category_id'] : (int.tryParse(json['category_id']?.toString() ?? '0') ?? 0),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0.0') ?? 0.0,
      discountPrice: json['discount_price'] != null ? double.tryParse(json['discount_price'].toString()) : null,
      stock: int.tryParse(json['stock']?.toString() ?? '0') ?? 0,
      condition: json['condition']?.toString() ?? 'new',
      thumbnail: json['thumbnail']?.toString() ?? '',
      images: imageList,
      status: json['status']?.toString() ?? 'active',
      specs: (json['specs'] as List?)?.map((i) => PhoneSpecModel.fromJson(i)).toList() ?? [],
      reviews: (json['reviews'] as List?)?.map((i) => ReviewModel.fromJson(i)).toList() ?? [],
      shop: json['shop'] != null ? ShopModel.fromJson(json['shop']) : null,
      brand: json['brand'] != null ? BrandModel.fromJson(json['brand']) : null,

    );
  }

}
