import 'package:flutter/material.dart';
import '../data/models/chat_model.dart';
import '../data/models/conversation_model.dart';
import '../data/repositories/api_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<ChatModel> _messages = [];
  List<ConversationModel> _conversations = [];
  bool _isSending = false;
  bool _isLoading = false;

  List<ChatModel> get messages => _messages;
  List<ConversationModel> get conversations => _conversations;
  bool get isSending => _isSending;
  bool get isLoading => _isLoading;

  // 1. Lấy danh sách tin nhắn (Hỗ trợ Polling nạp ngầm)
  Future<void> fetchMessages(String token, int receiverId, {bool isSilent = false}) async {
    if (!isSilent) {
      _isLoading = true;
      notifyListeners();
    }
    try {
      final res = await _apiService.getMessages(token, receiverId);
      if (res.data['success'] == true) {
        final List rawList = res.data['data'];
        _messages = rawList.map((e) => ChatModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("❌ Lỗi nạp tin nhắn: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 2. Đánh dấu đã đọc (Xóa lỗi gạch đỏ ở ChatDetailScreen)
  Future<void> markAsRead(String token, int receiverId) async {
    try {
      await _apiService.markChatAsRead(token, receiverId);
      // Cập nhật lại danh sách hội thoại để mất badge "chưa đọc"
      fetchChatList(token);
    } catch (e) {
      debugPrint("❌ Lỗi đánh dấu đã đọc: $e");
    }
  }

  // 3. Gửi tin nhắn mới (Optimistic UI)
  Future<bool> sendMessage(String token, int toUserId, String messageContent) async {
    if (messageContent.trim().isEmpty) return false;

    // Không set _isSending = true ở đây để tránh giật lag UI (Optimistic UI)
    try {
      final res = await _apiService.sendChatMessage(token, toUserId, messageContent);

      // ✅ Kiểm tra status code và dữ liệu trả về
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = res.data['data'];
        if (data != null) {
          final newMessage = ChatModel.fromJson(data);
          _messages.add(newMessage);
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      debugPrint("❌ Lỗi gửi tin nhắn: $e");
    }
    return false;
  }

  // 4. Lấy danh sách hội thoại (Cho ChatListScreen)
  Future<void> fetchChatList(String token) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _apiService.getChatList(token);
      if (res.data['success'] == true) {
        final List rawList = res.data['data'];
        _conversations = rawList.map((e) => ConversationModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("❌ Lỗi tải danh sách hội thoại: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // 5. Xóa bộ nhớ tạm khi thoát phòng chat
  void clearMessages() {
    _messages = [];
    notifyListeners();
  }

}