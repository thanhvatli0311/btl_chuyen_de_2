class ChatModel {
  final int id;
  final int fromUserId;
  final int toUserId;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  ChatModel({
    required this.id,
    required this.fromUserId,
    required this.toUserId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] ?? 0,
      fromUserId: json['from_user_id'] ?? 0,
      toUserId: json['to_user_id'] ?? 0,
      message: json['message'] ?? json['content'] ?? '',
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toString()),
    );
  }
}