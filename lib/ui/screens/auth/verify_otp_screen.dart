import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import '../../../providers/base_provider.dart';
import 'reset_password_screen.dart';

class VerifyOTPScreen extends StatefulWidget {
  final String email;
  const VerifyOTPScreen({super.key, required this.email});

  @override
  State<VerifyOTPScreen> createState() => _VerifyOTPScreenState();
}

class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
  final _otpController = TextEditingController();
  bool isLoading = false;

  /// Chức năng: Giải phóng tài nguyên bộ nhớ khi Widget bị hủy khỏi cây Widget.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  /// Chức năng: Gửi mã OTP người dùng nhập lên máy chủ để kiểm tra tính hợp lệ.
  /// Tham số đầu vào: Không có (Sử dụng dữ liệu trực tiếp từ controller và widget).
  /// Giá trị trả về: Future<void> xử lý bất đồng bộ.
  Future<void> _verifyOTP() async {
    final otpText = _otpController.text.trim();

    /// Kiểm tra sơ bộ độ dài mã OTP tại máy khách trước khi gọi API.
    if (otpText.length < 6) {
      Fluttertoast.showToast(msg: "Mã OTP phải có 6 chữ số");
      return;
    }

    setState(() => isLoading = true);

    try {
      /// Truy cập tầng API thông qua Provider để thực hiện xác thực.
      final base = context.read<BaseProvider>();
      final res = await base.apiService.verifyOtp(widget.email, otpText);

      /// Xử lý phản hồi từ server Laravel.
      if (res.statusCode == 200 && res.data['success'] == true) {
        Fluttertoast.showToast(msg: "Xác thực thành công!");

        /// Điều hướng sang màn hình đặt lại mật khẩu nếu mã OTP chính xác.
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResetPasswordScreen(email: widget.email, otp: otpText),
            ),
          );
        }
      } else {
        /// Thông báo lỗi từ phía server (Mã hết hạn hoặc không đúng).
        Fluttertoast.showToast(
            msg: res.data['message'] ?? "Mã OTP không đúng",
            backgroundColor: Colors.red
        );
      }
    } catch (e) {
      /// Xử lý các lỗi ngoại lệ liên quan đến đường truyền mạng.
      Fluttertoast.showToast(
          msg: "Lỗi kết nối Server",
          backgroundColor: Colors.red
      );
    } finally {
      /// Luôn luôn tắt trạng thái tải dữ liệu sau khi kết thúc quá trình xử lý.
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    /// Lắng nghe có chọn lọc các thay đổi về giao diện và kích cỡ chữ từ Provider.
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);
    final px = context.select<BaseProvider, double>((p) => p.textOffset);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          children: [
            Text(
                "XÁC THỰC OTP",
                style: TextStyle(
                    fontSize: 22 + px,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black
                )
            ),
            const SizedBox(height: 10),
            Text(
                "Chúng tôi đã gửi mã 6 số đến Gmail của bạn.\nMã có hiệu lực trong 10 phút.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13 + px)
            ),
            const SizedBox(height: 50),

            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              /// Cấu hình ràng buộc kiểu dữ liệu và giới hạn độ dài cho ô nhập OTP.
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              /// Kích hoạt hàm xác thực ngay khi người dùng nhấn nút hoàn tất trên bàn phím ảo.
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _verifyOTP(),
              style: TextStyle(
                  fontSize: 32 + px,
                  letterSpacing: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0047AB)
              ),
              decoration: InputDecoration(
                hintText: "••••••",
                hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.grey[300]),
                enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.blueAccent, width: 2)
                ),
              ),
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0047AB),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                /// Chặn việc bấm nút nhiều lần trong khi đang chờ phản hồi từ API.
                onPressed: isLoading ? null : _verifyOTP,
                child: isLoading
                    ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                )
                    : Text(
                    "XÁC NHẬN MÃ",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15 + px
                    )
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}