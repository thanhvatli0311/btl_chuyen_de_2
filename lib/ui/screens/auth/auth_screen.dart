import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:dio/dio.dart';
import '../../../providers/base_provider.dart';
import '../../../data/repositories/api_service.dart';
import 'verify_otp_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  /// Khởi tạo dịch vụ API dùng chung cho toàn bộ trạng thái của màn hình.
  final ApiService _apiService = ApiService();

  bool isLogin = true;
  bool isShop = false;
  bool isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  /// Chức năng: Giải phóng tài nguyên của các bộ điều khiển nhập liệu khi không còn sử dụng.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  /// Chức năng: Thực hiện logic xác thực (Đăng nhập hoặc Đăng ký) gọi tới Server.
  /// Tham số đầu vào: [baseProvider] - Cung cấp các hàm xử lý trạng thái đăng nhập toàn cục.
  /// Giá trị trả về: Future<void> xử lý bất đồng bộ.
  Future<void> _handleAuth(BaseProvider baseProvider) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    /// Kiểm tra tính hợp lệ của dữ liệu đầu vào trước khi gửi yêu cầu.
    if (email.isEmpty || password.isEmpty || (!isLogin && name.isEmpty)) {
      Fluttertoast.showToast(msg: "Vui lòng nhập đầy đủ thông tin!");
      return;
    }

    setState(() => isLoading = true);

    try {
      if (isLogin) {
        /// Xử lý luồng Đăng nhập.
        final response = await _apiService.login(email, password);
        if (response.statusCode == 200 && response.data['success'] == true) {
          /// Lưu thông tin đăng nhập vào Provider và chuyển hướng người dùng.
          await baseProvider.handleLoginSuccess(
              response.data['access_token'].toString(),
              response.data['user']
          );
          Fluttertoast.showToast(msg: "Chào mừng bạn trở lại!");
        } else {
          Fluttertoast.showToast(msg: response.data['message'] ?? "Đăng nhập thất bại");
        }
      } else {
        /// Xử lý luồng Đăng ký tài khoản mới.
        final response = await _apiService.register({
          'name': name,
          'email': email,
          'password': password,
          'role': isShop ? 'shop' : 'customer',
        });

        if (response.statusCode == 201) {
          /// Tùy biến thông báo dựa trên vai trò người dùng vừa đăng ký.
          String msg = isShop
              ? "Đăng ký thành công! Đơn mở gian hàng đang chờ phê duyệt."
              : "Đăng ký thành công! Hãy đăng nhập nhé.";

          Fluttertoast.showToast(msg: msg, backgroundColor: Colors.green);
          setState(() {
            isLogin = true;
            _nameController.clear();
          });
        }
      }
    } on DioException catch (e) {
      /// Bắt lỗi từ phía thư viện mạng Dio.
      _handleDioError(e);
    } finally {
      /// Đảm bảo tắt vòng xoay tải dữ liệu kể cả khi thành công hay gặp lỗi.
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Chức năng: Phân tích và hiển thị thông báo lỗi chi tiết từ máy chủ hoặc lỗi mạng.
  /// Tham số đầu vào: [e] - Đối tượng lỗi DioException.
  /// Giá trị trả về: Không có.
  void _handleDioError(DioException e) {
    String errorMsg = "Không thể kết nối tới máy chủ. Vui lòng kiểm tra mạng!";

    /// Kiểm tra nếu là lỗi quá hạn thời gian kết nối.
    if (e.type == DioExceptionType.connectionTimeout) errorMsg = "Kết nối quá hạn, vui lòng thử lại!";

    if (e.response != null) {
      final data = e.response?.data;
      if (data is Map) {
        /// Ưu tiên hiển thị lỗi validate từ Backend gửi về (Laravel).
        if (data['errors'] != null) {
          errorMsg = data['errors'].values.first[0].toString();
        } else {
          errorMsg = data['message'] ?? "Lỗi xác thực người dùng";
        }
      }
    }
    Fluttertoast.showToast(msg: errorMsg, backgroundColor: Colors.red);
  }

  @override
  Widget build(BuildContext context) {
    /// Lắng nghe chọn lọc sự thay đổi về giao diện và cỡ chữ.
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);
    final px = context.select<BaseProvider, double>((p) => p.textOffset);
    final baseProvider = context.read<BaseProvider>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          /// Hiệu ứng cuộn vật lý giúp giao diện mượt mà hơn trên các thiết bị Android.
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Icon(Icons.phonelink_setup_rounded, size: 80, color: Color(0xFF0047AB)),
              const SizedBox(height: 12),
              Text(
                "PHONE MARKET",
                style: TextStyle(
                  fontSize: 24 + px,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  color: isDark ? Colors.white : const Color(0xFF0047AB),
                ),
              ),
              const SizedBox(height: 40),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10)
                    )
                  ],
                ),
                child: Column(
                  children: [
                    _buildTabSwitcher(isDark, px),
                    const SizedBox(height: 30),

                    /// Trường nhập tên chỉ hiển thị khi người dùng chọn Đăng ký.
                    if (!isLogin) _buildCleanField(_nameController, "Họ và tên", Icons.person_outline, isDark, px),

                    _buildCleanField(_emailController, "Email đăng nhập", Icons.alternate_email, isDark, px),
                    _buildCleanField(_passwordController, "Mật khẩu", Icons.lock_outline, isDark, px, isObscure: true),

                    if (isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => _showForgotPasswordDialog(isDark, px),
                          child: Text("Quên mật khẩu?", style: TextStyle(color: Colors.blueAccent, fontSize: 13 + px)),
                        ),
                      ),

                    /// Nút chuyển đổi vai trò (Người mua/Shop) khi tạo tài khoản.
                    if (!isLogin) _buildShopSwitch(isDark, px),
                    const SizedBox(height: 24),
                    _buildMainButton(baseProvider, px),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Chức năng: Xây dựng hàng nút chuyển đổi giữa hai chế độ Đăng nhập và Đăng ký.
  /// Tham số đầu vào: [isDark], [px].
  /// Giá trị trả về: Widget dạng Row chứa các nút chuyển tab.
  Widget _buildTabSwitcher(bool isDark, double px) {
    return Row(
      children: [
        _tabButton("Đăng nhập", isLogin, px, () => setState(() => isLogin = true)),
        _tabButton("Đăng ký", !isLogin, px, () => setState(() => isLogin = false)),
      ],
    );
  }

  /// Chức năng: Xây dựng thành phần nút bấm đơn lẻ trong bộ chuyển tab.
  /// Tham số đầu vào: [title] (tên tab), [active] (trạng thái đang chọn), [px], [onTap].
  /// Giá trị trả về: Widget Tab đơn.
  Widget _tabButton(String title, bool active, double px, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Text(title, style: TextStyle(color: active ? const Color(0xFF0047AB) : Colors.grey, fontWeight: FontWeight.bold, fontSize: 14 + px)),
            const SizedBox(height: 8),
            /// Đường kẻ chỉ báo Tab đang được chọn có hiệu ứng chuyển động.
            AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 3,
                width: active ? 40 : 0,
                color: const Color(0xFF0047AB)
            ),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Tạo ô nhập liệu đồng bộ cho giao diện đăng nhập.
  /// Tham số đầu vào: [ctrl], [label], [icon], [isDark], [px], [isObscure] (ẩn mật khẩu).
  /// Giá trị trả về: Widget ô nhập liệu chuẩn.
  Widget _buildCleanField(TextEditingController ctrl, String label, IconData icon, bool isDark, double px, {bool isObscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: ctrl,
        obscureText: isObscure,
        /// Điều chỉnh nút chức năng trên bàn phím (Tiếp theo hoặc Hoàn tất).
        textInputAction: isObscure ? TextInputAction.done : TextInputAction.next,
        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14 + px),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20, color: Colors.blueAccent),
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
      ),
    );
  }

  /// Chức năng: Xây dựng bộ nút gạt để người dùng đăng ký dưới tư cách là Cửa hàng (Shop).
  /// Tham số đầu vào: [isDark], [px].
  /// Giá trị trả về: Widget hàng chứa văn bản và nút Switch.
  Widget _buildShopSwitch(bool isDark, double px) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Bạn muốn mở gian hàng?", style: TextStyle(fontSize: 13 + px)),
          Switch(
              value: isShop,
              activeColor: Colors.orangeAccent,
              onChanged: (val) => setState(() => isShop = val)
          ),
        ],
      ),
    );
  }

  /// Chức năng: Tạo nút bấm chính để xác nhận hành động của người dùng.
  /// Tham số đầu vào: [baseProvider], [px].
  /// Giá trị trả về: Widget nút bấm thực thi Auth.
  Widget _buildMainButton(BaseProvider baseProvider, double px) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0047AB),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        onPressed: isLoading ? null : () => _handleAuth(baseProvider),
        child: isLoading
            ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
        )
            : Text(isLogin ? "ĐĂNG NHẬP" : "KHỞI TẠO TÀI KHOẢN",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15 + px)),
      ),
    );
  }

  /// Chức năng: Hiển thị hộp thoại nhập Email để yêu cầu khôi phục mật khẩu.
  /// Tham số đầu vào: [isDark], [px].
  /// Giá trị trả về: Không có (Mở một Dialog UI).
  void _showForgotPasswordDialog(bool isDark, double px) {
    final TextEditingController emailCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Khôi phục mật khẩu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 + px)),
        content: TextField(
          controller: emailCtrl,
          decoration: InputDecoration(
              hintText: "Nhập Email đăng ký",
              filled: true,
              fillColor: Colors.grey.withOpacity(0.1),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0047AB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
            onPressed: () async {
              final email = emailCtrl.text.trim();
              if (email.isEmpty) return;

              /// Gọi API gửi mã OTP về email người dùng.
              final res = await _apiService.sendOtp(email);

              if (res.data['success'] == true) {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  /// Chuyển tới màn hình nhập mã xác thực OTP.
                  Navigator.push(context, MaterialPageRoute(builder: (_) => VerifyOTPScreen(email: email)));
                }
              } else {
                Fluttertoast.showToast(
                    msg: res.data['message'] ?? "Email không tồn tại!",
                    backgroundColor: Colors.orange
                );
              }
            },
            child: const Text("Gửi mã OTP", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}