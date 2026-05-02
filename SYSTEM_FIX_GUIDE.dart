// ============================================================================
// 🔧 HƯỚNG DẪN FIX HỆ THỐNG - Chi Tiết & So Sánh Code Trước/Sau
// ============================================================================

// ============================================================================
// 🔴 FIX 1: NotificationProvider - Logic Sai Tại Line 43
// ============================================================================
// 📂 File: lib/providers/notification_provider.dart
// ❌ TRƯỚC (SAI):
/*
  Future<void> markAsRead(String token, int id) async {
    try {
      final res = await _apiService.markNotificationRead(token, id);
      if (res.data['success'] == true) {
        final index = _notifications.indexWhere((n) => n.id == id);
        if (index != -index) {  // ❌ SAI: -index không phải -1
          _notifications[index] = NotificationModel(
            id: _notifications[index].id,
            userId: _notifications[index].userId,
            title: _notifications[index].title,
            content: _notifications[index].content,
            isRead: true,
            readAt: DateTime.now(),
            createdAt: _notifications[index].createdAt,
          );
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint("❌ Lỗi đánh dấu thông báo: $e");
    }
  }
*/

// ✅ SAU (ĐÚNG):
/*
  Future<void> markAsRead(String token, int id) async {
    try {
      final res = await _apiService.markNotificationRead(token, id);
      if (res.data['success'] == true) {
        final index = _notifications.indexWhere((n) => n.id == id);
        if (index != -1) {  // ✅ ĐÚNG: -1 là chỉ số không tìm thấy
          _notifications[index] = NotificationModel(
            id: _notifications[index].id,
            userId: _notifications[index].userId,
            title: _notifications[index].title,
            content: _notifications[index].content,
            isRead: true,  // ✅ Đánh dấu đã đọc
            readAt: DateTime.now(),  // ✅ Lưu thời điểm đọc
            createdAt: _notifications[index].createdAt,
          );
          notifyListeners();  // ✅ Thông báo UI vẽ lại
        }
      }
    } catch (e) {
      debugPrint("❌ Lỗi đánh dấu thông báo: $e");
    }
  }
*/

// 📊 Giải thích:
// - indexWhere() trả về index (>=0) nếu tìm thấy, hoặc -1 nếu không
// - Phép toán -index khi index=-1 sẽ cho kết quả 1, điều kiện sai
// - Phải kiểm tra index != -1 mới đúng

// ============================================================================
// 🟡 FIX 2: ApiService - Thống Nhất Sử Dụng Helper _auth()
// ============================================================================
// 📂 File: lib/data/repositories/api_service.dart
// 📍 Vị trí: Lines 309-354

// ❌ TRƯỚC (INCONSISTENT):
/*
  /// Lấy thông số Dashboard cho Admin
  Future<Response> getAdminDashboardStats(String token) async {
    return await _dio.get(
      '/admin/dashboard-stats',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
      // ❌ Tạo Options trực tiếp, thiếu Accept header, content-type không nhất quán
    );
  }

  /// Lấy danh sách cài đặt hệ thống (Phí sàn, tiền cọc)
  Future<Response> getSystemSettings(String token) async {
    return await _dio.get(
      '/admin/settings',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
      // ❌ Lặp lại pattern inconsistent
    );
  }
*/

// ✅ SAU (CONSISTENT):
/*
  /// Lấy thông số Dashboard cho Admin
  /// 📖 Chức năng: Trả về tổng doanh thu, số đơn, số shop cho Dashboard Admin
  Future<Response> getAdminDashboardStats(String token) async {
    return await _dio.get(
      '/admin/dashboard-stats',
      options: _auth(token),  // ✅ Dùng helper thống nhất
      // ✅ Tự động thêm:
      //    - Accept: application/json
      //    - Authorization: Bearer {token}
      //    - Content-Type: application/json
    );
  }

  /// Lấy danh sách cài đặt hệ thống (Phí sàn, tiền cọc)
  /// 📖 Chức năng: Lấy toàn bộ settings từ bảng system_settings
  Future<Response> getSystemSettings(String token) async {
    return await _dio.get(
      '/admin/settings',
      options: _auth(token),  // ✅ Dùng helper thống nhất
    );
  }

  /// Cập nhật một giá trị cài đặt hệ thống
  /// 📖 Chức năng: Thay đổi 1 setting (ví dụ: platform_fee = 2.5%)
  Future<Response> updateSystemSetting(String token, String key, String value) async {
    return await _dio.post(
      '/admin/settings/update',
      data: {'key_name': key, 'value': value},
      options: _auth(token),  // ✅ Dùng helper thống nhất
    );
  }

  /// Lấy danh sách các lệnh rút tiền đang chờ duyệt
  /// 📖 Chức năng: Admin xem những yêu cầu rút tiền chưa xử lý từ shop
  Future<Response> getWithdrawRequests(String token) async {
    return await _dio.get(
      '/admin/withdraw-requests',
      options: _auth(token),  // ✅ Dùng helper thống nhất
    );
  }

  /// Phê duyệt lệnh rút tiền (Gửi mã giao dịch ngân hàng)
  /// 📖 Chức năng: Admin duyệt request rút tiền, gửi reference_id (mã đã chuyển)
  Future<Response> approveWithdraw(String token, int id, String referenceId) async {
    return await _dio.post(
      '/admin/withdraw-requests/$id/approve',
      data: {'reference_id': referenceId},
      options: _auth(token),  // ✅ Dùng helper thống nhất
    );
  }

  /// Lấy danh sách Shop theo trạng thái (Duyệt Shop)
  /// 📖 Chức năng: Admin duyệt/từ chối các đơn đăng ký mở gian hàng
  Future<Response> getAdminShops(String token, {String? status}) async {
    return await _dio.get(
      '/admin/shops',
      queryParameters: status != null ? {'status': status} : null,
      options: _auth(token),  // ✅ Dùng helper thống nhất
    );
  }

  /// Thay đổi trạng thái Shop (Chấp nhận/Từ chối)
  /// 📖 Chức năng: Admin cập nhật shop.status từ pending→approved/rejected
  Future<Response> updateShopStatus(String token, int shopId, String status) async {
    return await _dio.put(
      '/admin/shops/$shopId/status',
      data: {'status': status},
      options: _auth(token),  // ✅ Dùng helper thống nhất
    );
  }
*/

// 📊 So Sánh Helper _auth():
/*
  /// Helper _auth() - Hợp nhất header & content-type
  Options _auth(String? token, {bool isMultipart = false}) => Options(
    headers: {
      'Accept': 'application/json',  // ✅ Header này đôi khi quan trọng
      if (token != null) 'Authorization': 'Bearer $token'  // ✅ Luôn cần
    },
    contentType: isMultipart ? 'multipart/form-data' : 'application/json',
    // ✅ Tự động chọn type dựa trên dữ liệu
  );
*/

// ============================================================================
// 🟠 FIX 3: Chat Screens - Sử Dụng px (textOffset) Toàn Bộ
// ============================================================================
// 📂 File: lib/ui/screens/chat/chat_detail_screen.dart & chat_list_screen.dart

// 📖 Hiểu về biến `px` từ BaseProvider:
/*
  // Trong base_provider.dart:
  double _textOffset = 0.0;  // Từ -4 đến 4
  double get textOffset => _textOffset;

  Future<void> updateTextOffset(double offset) async {
    _textOffset = offset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('text_offset', offset);  // ✅ Lưu vào phone
    notifyListeners();  // ✅ Thông báo tất cả screens cập nhật UI
  }

  // Sử dụng:
  final base = context.watch<BaseProvider>();
  final px = base.textOffset;  // Lấy offset
*/

// ❌ TRƯỚC (INCONSISTENT - một số nơi dùng, một số không):
/*
  // ✅ ĐÚNG
  Text(widget.otherUserName,
    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 + px));

  // ✅ ĐÚNG
  Text("Đang trực tuyến",
    style: TextStyle(fontSize: 10 + px, color: Colors.green));

  // ✅ ĐÚNG
  Text(msg.message,
    style: TextStyle(
      color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
      fontSize: 14 + px,  // ✅ Có dùng
      height: 1.3,
    ),
  );

  // ❌ THIẾU
  Text(timeStr,
    style: TextStyle(
      color: isMe ? Colors.white70 : Colors.grey,
      fontSize: 9,  // ❌ Thiếu + px
    ),
  );
*/

// ✅ SAU (THỐNG NHẤT):
/*
  Widget _buildChatBubble(ChatModel msg, bool isMe, double px, bool isDark) {
    return Align(
      // ...existing code...
      child: Container(
        // ...existing code...
        child: Column(
          // ...existing code...
          children: [
            Text(
              msg.message,
              style: TextStyle(
                color: isMe ? Colors.white : (isDark ? Colors.white : Colors.black87),
                fontSize: 14 + px,  // ✅ ĐÚNG: Sử dụng px
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('HH:mm').format(msg.createdAt),
              style: TextStyle(
                color: isMe ? Colors.white70 : Colors.grey,
                fontSize: 9 + px,  // ✅ FIX: Thêm + px
              ),
            ),
          ],
        ),
      ),
    );
  }
*/

// ============================================================================
// 📊 BẢNG KIỂM SOÁT - TRẠNG THÁI CÁC NHÓM VẤN ĐỀ
// ============================================================================

/*
┌──────────────────────────────────┬────────┬─────────────────────────────────┐
│ VẤN ĐỀ                           │ MỨC IV │ BIỆN PHÁP                       │
├──────────────────────────────────┼────────┼─────────────────────────────────┤
│ 1. NotifProvider logic sai       │ 🔴 RED │ Fix: index != -1 (không -index)  │
│                                  │        │ Thêm ghi chú chức năng cleartext │
├──────────────────────────────────┼────────┼─────────────────────────────────┤
│ 2. ApiService inconsistent _auth │ 🟡 YEL │ Thay 9 hàm Admin dùng _auth()   │
│                                  │        │ Thêm docstring giải thích API    │
├──────────────────────────────────┼────────┼─────────────────────────────────┤
│ 3. Chat screens missing px       │ 🟠 ORA │ Thêm px vào 1 dòng timeStr      │
│                                  │        │ Ghi chú lý do dùng px           │
├──────────────────────────────────┼────────┼─────────────────────────────────┤
│ 4. API endpoint verification     │ ✅ CHK │ Đời kiểm tra routes Laravel     │
│                                  │        │ (Ngoài phạm vi Dart)            │
└──────────────────────────────────┴────────┴─────────────────────────────────┘
*/

// ============================================================================
// 📝 GHI CHÚ THÊM - CÁC HÀNG TỐT NHẤT
// ============================================================================

// 1. Luôn dùng _auth(token) helper thay vì tạo Options trực tiếp
//    Lợi ích: Nhất quán, dễ bảo trì, tránh quên header

// 2. Thêm docstring (///) cho mỗi API endpoint
//    Nội dung: Chức năng, tham số, trả về

// 3. Sử dụng css variable (px, isDark) từ BaseProvider cho toàn bộ text
//    Lợi ích: Hỗ trợ accessibility, respons với font settings

// 4. Kiểm tra indexWhere kết quả luôn so với -1, không phải -0 hoặc -index

// 5. Comment lại code cũ khi thay đổi lớn để dễ so sánh

// ============================================================================

