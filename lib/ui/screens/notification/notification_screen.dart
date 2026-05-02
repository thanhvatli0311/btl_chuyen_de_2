import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/notification_provider.dart';
import '../../../providers/base_provider.dart';
import 'package:intl/intl.dart';

/// Chức năng: Hiển thị danh sách thông báo của người dùng.
/// Thiết kế: Minimalism, Card-based, hỗ trợ vuốt để xóa.
class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    /// Khởi tạo dữ liệu thông báo ngay khi vào màn hình.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<BaseProvider>().token;
      if (token != null) {
        context.read<NotificationProvider>().fetchNotifications(token);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final notiProvider = context.watch<NotificationProvider>();
    final token = context.read<BaseProvider>().token;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async => notiProvider.fetchNotifications(token!),
        child: notiProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : notiProvider.notifications.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: notiProvider.notifications.length,
          itemBuilder: (context, index) {
            final item = notiProvider.notifications[index];

            /// Sử dụng Dismissible để hỗ trợ tính năng vuốt để xóa hiện đại.
            return Dismissible(
              key: Key(item.id.toString()),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              onDismissed: (direction) {
                notiProvider.removeNotification(token!, item.id);
              },
              child: _buildNotificationCard(context, item, token!),
            );
          },
        ),
      ),
    );
  }

  /// Widget: Thẻ thông báo Card-based.
  Widget _buildNotificationCard(BuildContext context, dynamic item, String token) {
    return GestureDetector(
      onTap: () {
        if (!item.isRead) {
          context.read<NotificationProvider>().markAsRead(token, item.id);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          /// Màu nền thay đổi nhẹ dựa trên trạng thái đã đọc hay chưa.
          color: item.isRead ? Theme.of(context).cardColor : const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.isRead ? Colors.grey.withOpacity(0.1) : Colors.blue.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIcon(item.isRead),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontWeight: item.isRead ? FontWeight.w500 : FontWeight.bold,
                            fontSize: 15,
                            color: item.isRead ? Colors.grey.shade700 : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(item.createdAt),
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.content,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(bool isRead) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isRead ? Colors.grey.shade100 : Colors.blue.shade50,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.notifications_active_outlined,
        size: 20,
        color: isRead ? Colors.grey : const Color(0xFF0047AB),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none_rounded, size: 100, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('Hộp thư trống', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
        ],
      ),
    );
  }
}