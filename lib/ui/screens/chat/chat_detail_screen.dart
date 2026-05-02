import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../data/models/chat_model.dart';

class ChatDetailScreen extends StatefulWidget {
  final int receiverId;
  final String otherUserName;

  const ChatDetailScreen({
    super.key,
    required this.receiverId,
    required this.otherUserName
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollingTimer;

  /// Bộ định dạng thời gian tĩnh dùng chung để hiển thị giờ nhắn tin.
  /// Khai báo static final giúp tiết kiệm tài nguyên CPU bằng cách khởi tạo duy nhất một lần.
  static final DateFormat _timeFormatter = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    /// Đăng ký các tác vụ khởi tạo sau khi khung hình đầu tiên được dựng xong.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      _startPolling();
    });
  }

  /// Chức năng: Nạp danh sách tin nhắn ban đầu và đánh dấu đã xem.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void> xử lý bất đồng bộ.
  Future<void> _loadInitialData() async {
    /// Kiểm tra tính hợp lệ của ID người nhận trước khi gọi API.
    if (widget.receiverId == 0) {
      Fluttertoast.showToast(msg: "ID người nhận không hợp lệ");
      return;
    }

    final chatProv = context.read<ChatProvider>();
    final base = context.read<BaseProvider>();

    if (base.token != null) {
      /// Tải lịch sử chat và tự động cuộn xuống tin nhắn mới nhất.
      await chatProv.fetchMessages(base.token!, widget.receiverId);
      _scrollToBottom();
      /// Gửi yêu cầu cập nhật trạng thái đã xem cho các tin nhắn trong hội thoại này.
      chatProv.markAsRead(base.token!, widget.receiverId);
    }
  }

  /// Chức năng: Thiết lập cơ chế tự động cập nhật tin nhắn mới sau mỗi khoảng thời gian.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  void _startPolling() {
    /// Tạo vòng lặp thời gian định kỳ 5 giây một lần.
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      /// Ngừng polling nếu người dùng đã thoát khỏi màn hình chat.
      if (!mounted) {
        timer.cancel();
        return;
      }

      final base = context.read<BaseProvider>();
      final chatProv = context.read<ChatProvider>();

      /// Chỉ gọi API nạp tin nhắn nếu phiên đăng nhập hợp lệ và không trong trạng thái đang tải thủ công.
      if (base.token != null && !chatProv.isLoading) {
        chatProv.fetchMessages(base.token!, widget.receiverId, isSilent: true);
      }
    });
  }

  /// Chức năng: Tự động cuộn danh sách xuống vị trí tin nhắn cuối cùng.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  void _scrollToBottom() {
    if (!mounted) return;
    /// Đợi một khoảng thời gian ngắn để giao diện kịp dựng xong các bubble mới trước khi cuộn.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Chức năng: Thu dọn tài nguyên và hủy các bộ điều khiển khi đóng màn hình.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  @override
  void dispose() {
    /// Hủy bộ hẹn giờ polling để tránh rò rỉ bộ nhớ và lãng phí request API.
    _pollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /// Lắng nghe chọn lọc các thay đổi về cấu hình giao diện và cỡ chữ từ BaseProvider.
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);
    final px = context.select<BaseProvider, double>((p) => p.textOffset);
    final token = context.select<BaseProvider, String?>((p) => p.token);

    /// Theo dõi danh sách tin nhắn và trạng thái tải từ ChatProvider.
    final messages = context.select<ChatProvider, List<ChatModel>>((p) => p.messages);
    final isLoading = context.select<ChatProvider, bool>((p) => p.isLoading);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.otherUserName.isEmpty ? "Người dùng #${widget.receiverId}" : widget.otherUserName,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 + px),
            ),
            const Text("Đang hoạt động", style: TextStyle(fontSize: 10, color: Colors.green)),
          ],
        ),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          Expanded(
            child: isLoading && messages.isEmpty
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _buildMessageList(messages, px, isDark),
          ),
          _buildInputArea(token ?? "", px, isDark),
        ],
      ),
    );
  }

  /// Chức năng: Xây dựng khung danh sách hiển thị các tin nhắn.
  /// Tham số đầu vào: [messages] danh sách dữ liệu, [px] cỡ chữ, [isDark] chế độ tối.
  /// Giá trị trả về: Widget dạng ListView.
  Widget _buildMessageList(List<ChatModel> messages, double px, bool isDark) {
    /// Hiển thị thông báo gợi ý nếu chưa có lịch sử trò chuyện.
    if (messages.isEmpty) {
      return Center(child: Text("Bắt đầu trò chuyện với ${widget.otherUserName}", style: const TextStyle(color: Colors.grey)));
    }

    final userId = context.read<BaseProvider>().user?.id;

    return ListView.builder(
      controller: _scrollController,
      /// Tối ưu vùng đệm cuộn để các bubble tin nhắn hiển thị mượt mà hơn trên Android.
      cacheExtent: 500,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        /// Xác định tin nhắn là của bản thân gửi hay của đối phương.
        final bool isMe = msg.fromUserId == userId;
        return _buildChatBubble(msg, isMe, px, isDark);
      },
    );
  }

  /// Chức năng: Tạo giao diện bong bóng chat cho từng tin nhắn đơn lẻ.
  /// Tham số đầu vào: [msg] dữ liệu tin, [isMe] cờ xác định người gửi, [px] cỡ chữ, [isDark].
  /// Giá trị trả về: Widget chứa nội dung tin nhắn và thời gian.
  Widget _buildChatBubble(ChatModel msg, bool isMe, double px, bool isDark) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe
              ? const Color(0xFF0047AB)
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            /// Tùy biến bo góc để phân biệt hướng tin nhắn (trái/phải).
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.message,
              style: TextStyle(
                color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                fontSize: 14 + px,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              /// Hiển thị thời gian gửi tin nhắn dựa trên bộ định dạng tĩnh đã khai báo.
              _timeFormatter.format(msg.createdAt),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey,
                fontSize: 9 + px,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Xây dựng khu vực nhập liệu tin nhắn ở dưới cùng màn hình.
  /// Tham số đầu vào: [token] xác thực, [px] cỡ chữ, [isDark] chế độ tối.
  /// Giá trị trả về: Widget chứa TextField và nút Gửi.
  Widget _buildInputArea(String token, double px, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                /// Cho phép nhấn nút Gửi trực tiếp từ bàn phím ảo của điện thoại.
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _handleSendMessage(token),
                decoration: InputDecoration(
                    hintText: "Nhập tin nhắn...",
                    hintStyle: TextStyle(fontSize: 14 + px),
                    border: InputBorder.none
                ),
                maxLines: null,
              ),
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _handleSendMessage(token),
            icon: const Icon(Icons.send_rounded, color: Color(0xFF0047AB)),
          ),
        ],
      ),
    );
  }

  /// Chức năng: Xử lý logic khi người dùng thực hiện hành động gửi tin nhắn.
  /// Tham số đầu vào: [token] xác thực người dùng.
  /// Giá trị trả về: Không có (Thực hiện gọi API bất đồng bộ).
  void _handleSendMessage(String token) async {
    final text = _messageController.text.trim();
    /// Chặn gửi tin nhắn nếu nội dung rỗng hoặc chỉ có khoảng trắng.
    if (text.isEmpty) return;

    /// Xóa trắng ô nhập liệu ngay lập tức để tạo cảm giác mượt mà cho người dùng.
    _messageController.clear();
    final success = await context.read<ChatProvider>().sendMessage(token, widget.receiverId, text);

    /// Nếu gửi thành công trên Server, cuộn danh sách xuống để thấy tin nhắn vừa gửi.
    if (success) {
      _scrollToBottom();
    }
  }
}