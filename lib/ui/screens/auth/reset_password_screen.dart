import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../../providers/base_provider.dart';
import '../../../data/repositories/api_service.dart';
import 'auth_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String otp;
  const ResetPasswordScreen({super.key, required this.email, required this.otp});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool isLoading = false;

  /// Chức năng: Giải phóng tài nguyên bộ nhớ khi Widget bị hủy.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  @override
  void dispose() {
    /// Hủy các bộ điều khiển văn bản để tránh tình trạng rò rỉ bộ nhớ (Memory Leak).
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Chức năng: Xử lý logic kiểm tra thông tin và gửi yêu cầu đặt lại mật khẩu lên hệ thống.
  /// Tham số đầu vào: Không có (Sử dụng dữ liệu trực tiếp từ Controller và Widget).
  /// Giá trị trả về: Future<void> xử lý bất đồng bộ.
  Future<void> _resetPassword() async {
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    /// Kiểm tra các trường nhập liệu không được để trống.
    if (newPass.isEmpty || confirmPass.isEmpty) {
      Fluttertoast.showToast(msg: "Vui lòng nhập mật khẩu mới");
      return;
    }

    /// Xác nhận mật khẩu nhập lại phải khớp hoàn toàn với mật khẩu mới.
    if (newPass != confirmPass) {
      Fluttertoast.showToast(msg: "Mật khẩu không trùng khớp");
      return;
    }

    setState(() => isLoading = true);

    try {
      /// Truy cập ApiService thông qua Provider để thực hiện gọi API.
      final apiService = context.read<BaseProvider>().apiService;

      final res = await apiService.resetPassword({
        'email': widget.email,
        'otp_code': widget.otp,
        'password': newPass,
        'password_confirmation': confirmPass,
      });

      /// Xử lý kết quả trả về từ máy chủ Laravel.
      if (res['success'] == true) {
        Fluttertoast.showToast(msg: "Đổi mật khẩu thành công!");

        /// Nếu đổi thành công, chuyển hướng người dùng về màn hình đăng nhập và xóa toàn bộ lịch sử điều hướng.
        if (mounted) {
          Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false
          );
        }
      } else {
        /// Hiển thị thông báo lỗi từ phía máy chủ nếu có.
        Fluttertoast.showToast(msg: res['message'] ?? "Lỗi cập nhật!");
      }
    } catch (e) {
      /// Xử lý trường hợp mất kết nối mạng hoặc lỗi hệ thống không xác định.
      Fluttertoast.showToast(msg: "Lỗi kết nối Server");
    } finally {
      /// Đảm bảo tắt trạng thái tải dữ liệu sau khi kết thúc tác vụ.
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    /// Lấy thông tin trạng thái giao diện và cấu hình cỡ chữ từ Provider toàn cục.
    final base = context.watch<BaseProvider>();
    final isDark = base.isDarkMode;
    final px = base.textOffset;

    return Scaffold(
      /// Đồng bộ màu nền theo chế độ Sáng/Tối của ứng dụng.
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("MẬT KHẨU MỚI", style: TextStyle(fontSize: 16 + px, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0047AB),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            /// Thành phần nhập mật khẩu mới.
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              /// Cấu hình nút nhấn trên bàn phím để chuyển nhanh sang ô tiếp theo.
              textInputAction: TextInputAction.next,
              style: TextStyle(fontSize: 14 + px),
              decoration: const InputDecoration(
                labelText: "Mật khẩu mới",
                prefixIcon: Icon(Icons.lock),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
              ),
            ),
            const SizedBox(height: 16),

            /// Thành phần nhập lại mật khẩu để xác nhận.
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              /// Khi nhấn nút "Xong" trên bàn phím, hệ thống tự động gọi hàm gửi dữ liệu.
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _resetPassword(),
              style: TextStyle(fontSize: 14 + px),
              decoration: const InputDecoration(
                labelText: "Xác nhận mật khẩu",
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
              ),
            ),
            const SizedBox(height: 30),

            /// Nút bấm chính để thực thi lệnh cập nhật mật khẩu.
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                /// Vô hiệu hóa nút khi đang trong quá trình xử lý API.
                onPressed: isLoading ? null : _resetPassword,
                child: isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text("CẬP NHẬT MẬT KHẨU", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15 + px)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}