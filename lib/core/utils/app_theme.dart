import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Lớp AppTheme chịu trách nhiệm định nghĩa toàn bộ phong cách giao diện (Theme) cho ứng dụng.
/// Lớp này cung cấp các cấu hình cho cả chế độ sáng (Light Mode) và chế độ tối (Dark Mode).
class AppTheme {
  static const bool _useMaterial3 = true;
  static const Color _primaryColor = Color(0xFF2563EB);

  /// Hàm khởi tạo cấu hình giao diện cho chế độ sáng (Light Mode).
  /// Tham số đầu vào: px - Giá trị điều chỉnh kích thước phông chữ linh hoạt.
  /// Giá trị trả về: Đối tượng ThemeData chứa các thiết lập giao diện sáng.
  static ThemeData lightTheme(double px) {
    return ThemeData(
      useMaterial3: _useMaterial3,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        background: const Color(0xFFF8FAFC),
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),

      /// Cấu hình giao diện cho các thành phần thẻ (Card).
      /// Thiết lập bo góc lớn và bóng đổ nhẹ để tạo hiệu ứng hiện đại.
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      ),

      /// Cấu hình thanh ứng dụng (AppBar).
      /// Kích thước chữ tiêu đề được tính toán dựa trên tham số px để hỗ trợ thay đổi cỡ chữ.
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.lexend(
          color: const Color(0xFF1E293B),
          fontSize: 18 + px,
          fontWeight: FontWeight.bold,
        ),
      ),

      /// Cấu hình mặc định cho các nút bấm dạng nổi (ElevatedButton).
      /// Nút bấm có bóng đổ dựa trên màu chủ đạo để tạo điểm nhấn thị giác.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          elevation: 4,
          shadowColor: _primaryColor.withOpacity(0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: GoogleFonts.lexend(fontSize: 14 + px, fontWeight: FontWeight.bold),
        ),
      ),

      /// Thiết lập kiểu chữ cho toàn bộ hệ thống văn bản trong ứng dụng.
      /// Mọi kiểu chữ đều được cộng thêm giá trị px để đồng bộ việc thay đổi kích cỡ chữ toàn app.
      textTheme: TextTheme(
        bodyLarge: GoogleFonts.lexend(fontSize: 16 + px),
        bodyMedium: GoogleFonts.lexend(fontSize: 14 + px),
        titleLarge: GoogleFonts.lexend(fontSize: 20 + px, fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Hàm khởi tạo cấu hình giao diện cho chế độ tối (Dark Mode).
  /// Tham số đầu vào: px - Giá trị điều chỉnh kích thước phông chữ linh hoạt.
  /// Giá trị trả về: Đối tượng ThemeData chứa các thiết lập giao diện tối.
  static ThemeData darkTheme(double px) {
    return ThemeData(
      useMaterial3: _useMaterial3,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primaryColor,
        brightness: Brightness.dark,
        background: const Color(0xFF0F172A),
        surface: const Color(0xFF1E293B),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),

      /// Cấu hình thẻ (Card) trong chế độ tối.
      /// Thay vì dùng bóng đổ đậm, thẻ được bao quanh bởi viền mờ để tách biệt với nền tối.
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      ),

      /// Cấu hình thanh ứng dụng (AppBar) cho chế độ tối.
      /// Màu sắc tiêu đề chuyển sang trắng để đảm bảo độ tương phản trên nền xanh đậm.
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.lexend(
          color: Colors.white,
          fontSize: 18 + px,
          fontWeight: FontWeight.bold,
        ),
      ),

      /// Cấu hình nút bấm nổi cho chế độ tối.
      /// Giữ nguyên phong cách bo góc 18px để đồng nhất với chế độ sáng.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: GoogleFonts.lexend(fontSize: 14 + px, fontWeight: FontWeight.bold),
        ),
      ),

      /// Thiết lập kiểu chữ cho chế độ tối.
      /// Màu chữ được điều chỉnh về trắng hoặc trắng mờ (white70) để dễ đọc trong môi trường thiếu sáng.
      textTheme: TextTheme(
        bodyLarge: GoogleFonts.lexend(fontSize: 16 + px, color: Colors.white),
        bodyMedium: GoogleFonts.lexend(fontSize: 14 + px, color: Colors.white70),
        titleLarge: GoogleFonts.lexend(fontSize: 20 + px, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}