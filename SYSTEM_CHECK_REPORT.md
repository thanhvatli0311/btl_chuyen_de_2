# 📋 BÁO CÁO KIỂM TRA HỆ THỐNG API & PROVIDERS

**Ngày kiểm tra:** 23/04/2026  
**Phàm vi:** Toàn hệ thống Dart/Flutter (lib/providers, lib/data/repositories, lib/ui/screens)

---

## 🔴 NHÓM VẤN ĐỀ 1: Logic Lỗi trong Providers

### Problem 1.1: NotificationProvider - Điều kiện so sánh Logic Sai
**File:** `lib/providers/notification_provider.dart` (Line 43)  
**Mô tả:** Kiểm tra index lỗi `if (index != -index)` sẽ luôn đúng, phải là `if (index != -1)`

**Ảnh hưởng:** Thông báo "đã đọc" không được cập nhật vào danh sách local, gây UI bị nhấp nháy.

**Fix:**
```dart
// ❌ SAI
if (index != -index) {

// ✅ ĐÚNG  
if (index != -1) {
```

---

## 🟡 NHÓM VẤN ĐỀ 2: Inconsistency trong ApiService - Sử Dụng Options Không Nhất Quán

### Problem 2.1: Admin Endpoints Không Dùng Helper `_auth()`
**File:** `lib/data/repositories/api_service.dart`  
**Các hàm bị ảnh hưởng:**
- `getAdminDashboardStats()` (Line 309)
- `getSystemSettings()` (Line 316)
- `updateSystemSetting()` (Line 323)
- `getWithdrawRequests()` (Line 331)
- `approveWithdraw()` (Line 339)
- `getAdminShops()` (Line 347)
- `updateShopStatus()` (Line 354)

**Vấn đề:** Tạo Options trực tiếp thay vì dùng helper `_auth()`, dẫn đến:
- Không có content-type mặc định
- Không có Accept header
- Code không nhất quán, khó bảo trì

**Ảnh hưởng:** Có thể gây conflict headers hoặc request không đúng format.

**Fix:**
```dart
// ❌ SAI
Future<Response> getAdminDashboardStats(String token) async {
  return await _dio.get(
    '/admin/dashboard-stats',
    options: Options(headers: {'Authorization': 'Bearer $token'}),
  );
}

// ✅ ĐÚNG
Future<Response> getAdminDashboardStats(String token) async {
  return await _dio.get(
    '/admin/dashboard-stats',
    options: _auth(token),
  );
}
```

---

## 🟠 NHÓM VẤN ĐỀ 3: Sử Dụng Biến `px` (textOffset) Chưa Hoàn Toàn

### Problem 3.1: Chat Screens Sử Dụng px Không Nhất Quán
**File:** 
- `lib/ui/screens/chat/chat_detail_screen.dart` (Line 77-79, 163, 168)
- `lib/ui/screens/chat/chat_list_screen.dart` (Line 46-48)

**Mô tả:** Một số nơi sử dụng `px` (textOffset) từ BaseProvider để điều chỉnh kích thước font, nhưng không phải lúc nào cũng sử dụng nhất quán.

**Chức năng của px:**
- `px` = `textOffset` từ BaseProvider, là Double từ -4.0 đến 4.0
- Dùng để tăng/giảm fontSize động: `FontSize: baseSize + px`
- Lưu vào SharedPreferences để nhớ tùy chọn người dùng

**Ảnh hưởng:** Nếu người dùng thay đổi textOffset trong Settings, một số text sẽ không thay đổi.

**Kiểm tra cách dùng đúng:**
```dart
// ✅ ĐÚNG - Chat tí cộng offset
Text("Tin nhắn", style: TextStyle(fontSize: 14 + px))

// ✅ ĐÚNG - Tiêu đề chính 
AppBar(title: Text("...", style: TextStyle(fontSize: 18 + px)))

// ✅ ĐÚNG - Hiển thị giờ
Text(timeStr, style: TextStyle(fontSize: 11 + px))
```

---

## 🟢 NHÓM VẤN ĐỀ 4: API Endpoints - Verification & Consistency

### Problem 4.1: Chat API Path Có Thể Không Khớp Laravel Routes
**File:** `lib/data/repositories/api_service.dart` (Line 417-421)

**Endpoint:**
```dart
Future<Response> getChatList(String token) => _dio.get('/chats', options: _auth(token));
Future<Response> getMessages(String token, int receiverId) => _dio.get('/chats/$receiverId', options: _auth(token));
Future<Response> sendChatMessage(String token, int toUserId, String message) =>
      _dio.post('/chats/send', data: {'to_user_id': toUserId, 'message': message}, options: _auth(token));
```

**Cần kiểm tra:** Laravel routes trong `be_api/routes/api.php` có định nghĩa chính xác không?

---

## 📊 TÓMS TẮT CÁC VẤN ĐỀ

| Vấn đề | File | Line | Mức Độ | Loại |
|-------|------|------|--------|------|
| Logic sai index check | notification_provider.dart | 43 | 🔴 High | Logic |
| Inconsistent `_auth()` usage | api_service.dart | 309-354 | 🟡 Medium | Consistency |
| px không nhất quán | chat_*_screen.dart | Multiple | 🟠 Low | UX |
| API path mismatch (cần verify) | api_service.dart | 417-421 | 🟠 Low | Verify |

---

## ✅ KIỂM SOÁT CHẤT LƯỢNG

### Các providers đã được xác nhận chính xác:
- ✅ `base_provider.dart` - Quản lý token, theme, textOffset
- ✅ `chat_provider.dart` - Sử dụng API đúng, có cả fetchChatList & conversations
- ✅ `cart_provider.dart` - Checkout logic chính xác
- ✅ `shop_provider.dart` - Inventory basic
- ✅ `admin_provider.dart` - Mỗi hàm gọi API đúng (khi kiểm tra chi tiết)
- ✅ `auth_screen.dart` - Gọi `handleLoginSuccess()` đúng cách

### Các file cần fix ngay:
- 🔴 `notification_provider.dart` - Line 43 (Logic)
- 🟡 `api_service.dart` - Lines 309-354 (Consistency)

---

## 🔧 HƯỚNG DẪN FIX

Xem file fix chi tiết: `SYSTEM_FIX_GUIDE.dart`

