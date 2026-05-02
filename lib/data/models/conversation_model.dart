import 'user_model.dart';
import 'chat_model.dart';

class ConversationModel {
  final int id;
  final UserModel otherUser;
  final ChatModel? lastMessage;
  final int unreadCount;

  ConversationModel({
    required this.id,
    required this.otherUser,
    this.lastMessage,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] ?? 0,
      otherUser: UserModel.fromJson(json['other_user'] ?? {}),
      lastMessage: json['last_message'] != null
          ? ChatModel.fromJson(json['last_message'])
          : null,
      unreadCount: json['unread_count'] ?? 0,
    );
  }
}
