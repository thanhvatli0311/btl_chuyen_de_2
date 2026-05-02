import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../core/utils/image_helper.dart';
import 'chat_detail_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  /// Bộ định dạng thời gian tĩnh dùng chung để hiển thị giờ nhắn tin cuối cùng.
  /// Khai báo static final giúp tối ưu tài nguyên CPU bằng cách khởi tạo duy nhất một lần.
  static final DateFormat _timeFormatter = DateFormat('HH:mm');

  @override
  void initState() {
    super.initState();
    /// Tự động nạp danh sách hội thoại ngay sau khi khung hình đầu tiên được dựng xong.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshChatList());
  }

  /// Chức năng: Gọi API lấy danh sách các cuộc hội thoại hiện có của người dùng.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void> xử lý bất đồng bộ.
  Future<void> _refreshChatList() async {
    final base = context.read<BaseProvider>();
    if (base.token != null) {
      /// Thực hiện yêu cầu tải dữ liệu thông qua ChatProvider.
      await context.read<ChatProvider>().fetchChatList(base.token!);
    }
  }

  @override
  Widget build(BuildContext context) {
    /// Lắng nghe chọn lọc các thay đổi về giao diện và cấu hình người dùng từ BaseProvider.
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);
    final px = context.select<BaseProvider, double>((p) => p.textOffset);
    final currentUserId = context.read<BaseProvider>().user?.id;

    /// Theo dõi trạng thái tải và danh sách dữ liệu từ ChatProvider.
    final isLoading = context.select<ChatProvider, bool>((p) => p.isLoading);
    final conversations = context.select<ChatProvider, List>((p) => p.conversations);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text("TIN NHẮN",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18 + px, letterSpacing: 1)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).cardColor,
        actions: [
          IconButton(
            /// Nút nhấn để người dùng chủ động làm mới danh sách tin nhắn.
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refreshChatList,
          )
        ],
      ),
      body: isLoading && conversations.isEmpty
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
        onRefresh: _refreshChatList,
        child: conversations.isEmpty
            ? _buildEmptyState(px, isDark)
            : ListView.builder(
          /// Cấu hình vùng đệm để ListView dựng sẵn các thẻ tin nhắn, giúp cuộn mượt hơn trên Android.
          cacheExtent: 500,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: conversations.length,
          itemBuilder: (context, index) {
            return _buildChatCard(conversations[index], px, isDark, currentUserId);
          },
        ),
      ),
    );
  }

  /// Chức năng: Xây dựng giao diện thẻ (Card) hiển thị thông tin tóm tắt của một hội thoại.
  /// Tham số đầu vào: [chat] dữ liệu hội thoại, [px] cỡ chữ, [isDark] chế độ tối, [currentUserId] ID người dùng hiện tại.
  /// Giá trị trả về: Widget dạng thẻ chứa thông tin người nhắn và nội dung cuối cùng.
  Widget _buildChatCard(dynamic chat, double px, bool isDark, int? currentUserId) {
    /// Kiểm tra xem tin nhắn cuối cùng có phải do chính mình gửi hay không.
    final bool isMe = chat.lastMessage?.fromUserId == currentUserId;

    /// Chuyển đổi thời gian tạo tin nhắn sang định dạng chuỗi HH:mm để hiển thị.
    final String timeStr = chat.lastMessage != null
        ? _timeFormatter.format(chat.lastMessage!.createdAt)
        : "";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              final int receiverId = chat.otherUser.id;
              /// Ràng buộc kiểm tra dữ liệu người nhận trước khi điều hướng.
              if (receiverId == 0) {
                Fluttertoast.showToast(msg: "Lỗi dữ liệu người dùng!");
                return;
              }

              /// Chuyển sang màn hình chat chi tiết và nạp lại danh sách khi quay về.
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatDetailScreen(
                    receiverId: receiverId,
                    otherUserName: chat.otherUser.name,
                  ),
                ),
              ).then((_) => _refreshChatList());
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Stack(
                    children: [
                      /// Hiển thị ảnh đại diện của đối phương.
                      ImageHelper.load(chat.otherUser.avatarUrl, width: 55, height: 55, borderRadius: 18),
                      /// Hiển thị dấu chấm xanh nếu đối phương đang trực tuyến.
                      if (chat.otherUser.isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Theme.of(context).cardColor, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              chat.otherUser.name,
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15 + px),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              timeStr,
                              style: TextStyle(color: Colors.grey, fontSize: 11 + px),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                /// Tiền tố "Bạn: " chỉ xuất hiện nếu mình là người gửi tin cuối.
                                "${isMe ? "Bạn: " : ""}${chat.lastMessage?.message ?? "Chưa có tin nhắn"}",
                                style: TextStyle(
                                  /// Làm đậm nội dung tin nhắn nếu có tin nhắn mới chưa đọc.
                                  color: (chat.unreadCount > 0) ? (isDark ? Colors.white : Colors.black87) : Colors.grey,
                                  fontWeight: (chat.unreadCount > 0) ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13 + px,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            /// Hiển thị vòng tròn số lượng tin nhắn chưa đọc.
                            if (chat.unreadCount > 0)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Color(0xFF0047AB), shape: BoxShape.circle),
                                child: Text(
                                  chat.unreadCount.toString(),
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Chức năng: Hiển thị giao diện thông báo khi người dùng chưa có bất kỳ tin nhắn nào.
  /// Tham số đầu vào: [px] cỡ chữ, [isDark] chế độ tối.
  /// Giá trị trả về: Widget căn giữa chứa biểu tượng và văn bản.
  Widget _buildEmptyState(double px, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 80, color: isDark ? Colors.white10 : Colors.grey[200]),
          const SizedBox(height: 20),
          Text("Chưa có cuộc hội thoại nào",
              style: TextStyle(fontSize: 16 + px, fontWeight: FontWeight.w700, color: isDark ? Colors.white54 : Colors.grey)),
        ],
      ),
    );
  }
}