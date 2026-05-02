// 📂 path: lib/data/models/review_model.dart
class ReviewModel {
  final int id;
  final int userId;
  final int rating;
  final String? comment;
  final String userName;
  final String? userAvatar;

  ReviewModel({
    required this.id,
    required this.userId,
    required this.rating,
    this.comment,
    required this.userName,
    this.userAvatar
  });

  factory ReviewModel.fromJson(Map<String, dynamic> json) {
    // Ép kiểu an toàn để tránh lỗi 'dynamic is not a subtype of String'
    return ReviewModel(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      rating: json['rating'] ?? 5,
      comment: json['comment'],
      // Logic bóc tách từ object 'user' trong JSON của Laravel
      userName: json['user']?['name'] ?? 'Người dùng',
      userAvatar: json['user']?['avatar'],
    );
  }
}