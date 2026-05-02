import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../data/models/notification_model.dart';
import '../data/repositories/api_service.dart';

/// Chức năng: Quản lý trạng thái và các thao tác với thông báo trong ứng dụng.
/// Sử dụng: Tích hợp đồng bộ giữa dữ liệu từ Laravel API và giao diện Flutter.
class NotificationProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Danh sách các thông báo được lưu trữ trong bộ nhớ tạm (State)
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;

  List<NotificationModel> get notifications => _notifications;
  bool get isLoading => _isLoading;

  /// Chức năng: Tính toán số lượng thông báo chưa đọc để hiển thị Badge (chấm đỏ) trên UI.
  /// Giá trị trả về: Số lượng thông báo có thuộc tính isRead là false.
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  /// Chức năng: Truy vấn danh sách thông báo từ Server.
  /// Tham số đầu vào: [token] mã định danh người dùng.
  Future<void> fetchNotifications(String token) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await _apiService.getNotifications(token);

      // Kiểm tra phản hồi từ Laravel thành công
      if (res.data['success'] == true) {
        // Dữ liệu phân trang của Laravel nằm trong data.data
        final List rawList = res.data['data']['data'];

        // Chuyển đổi dữ liệu thô (JSON) sang mảng các đối tượng NotificationModel
        _notifications = rawList.map((e) => NotificationModel.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("❌ Lỗi nạp thông báo: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Chức năng: Cập nhật trạng thái "đã đọc" cho một thông báo cụ thể.
  /// Tham số đầu vào: [token], [id] của thông báo cần xử lý.
  /// Đặc điểm: Sử dụng Optimistic Update để UI thay đổi ngay lập tức mà không chờ Server phản hồi.
  Future<void> markAsRead(String token, int id) async {
    try {
      final res = await _apiService.markNotificationRead(token, id);
      if (res.data['success'] == true) {

        // Tìm vị trí của thông báo trong danh sách hiện tại
        final index = _notifications.indexWhere((n) => n.id == id);

        if (index != -1) {
          // Tạo một bản sao mới với trạng thái đã đọc để kích hoạt notifyListeners()
          _notifications[index] = NotificationModel(
            id: _notifications[index].id,
            userId: _notifications[index].userId,
            title: _notifications[index].title,
            content: _notifications[index].content,
            isRead: true,
            readAt: DateTime.now(),
            createdAt: _notifications[index].createdAt,
          );

          // Thông báo cho toàn bộ các Widget đang lắng nghe để vẽ lại giao diện
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("❌ Lỗi đánh dấu thông báo: $e");
    }
  }

  /// Chức năng: Xóa bỏ hoàn toàn thông báo khỏi danh sách và Server.
  /// Tham số đầu vào: [token], [id] thông báo.
  Future<void> removeNotification(String token, int id) async {
    try {
      final res = await _apiService.deleteNotification(token, id);
      if (res.data['success'] == true) {
        // Xóa khỏi danh sách local ngay sau khi server xác nhận xóa thành công
        _notifications.removeWhere((n) => n.id == id);
        notifyListeners();

        Fluttertoast.showToast(
          msg: "Đã xóa thông báo thành công",
          backgroundColor: Colors.black87,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      debugPrint("❌ Lỗi khi xóa: $e");
      Fluttertoast.showToast(msg: "Không thể xóa thông báo lúc này");
    }
  }
}