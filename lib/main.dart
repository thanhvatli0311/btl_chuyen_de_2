import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'providers/address_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/base_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/chat_provider.dart';

import 'providers/news_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/revenue_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/shop_order_provider.dart';

import 'ui/screens/admin/admin_user_management_screen.dart';
import 'ui/screens/auth/auth_screen.dart';
import 'ui/screens/buyer/home_screen.dart';
import 'ui/screens/news/news_feed_screen.dart';
import 'ui/screens/profile/profile_screen.dart';
import 'ui/screens/seller/shop_order_screen.dart';
import 'ui/screens/seller/revenue_screen.dart';

import 'ui/screens/chat/chat_list_screen.dart';

/// Chức năng: Điểm khởi chạy chính của ứng dụng.
/// Tham số đầu vào: Không có.
/// Giá trị trả về: Không có.
void main() async {
  /// Đảm bảo các dịch vụ của Flutter đã được khởi tạo trước khi chạy App.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    /// Cấu hình hệ thống quản lý trạng thái tập trung (State Management).
    /// Khai báo toàn bộ các Provider để có thể truy cập dữ liệu ở bất kỳ đâu trong App.
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BaseProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ShopProvider()),
        ChangeNotifierProvider(create: (_) => RevenueProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ShopOrderProvider()),
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => AddressProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => NewsProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// Chức năng: Cấu hình giao diện gốc và điều hướng khởi đầu.
  /// Tham số đầu vào: [context] cung cấp thông tin về cây widget.
  /// Giá trị trả về: Widget MaterialApp.
  @override
  Widget build(BuildContext context) {
    /// Lắng nghe các thay đổi về giao diện (Sáng/Tối) từ BaseProvider.
    return Consumer<BaseProvider>(
      builder: (context, base, child) {
        return MaterialApp(
          title: 'TSP MARKET',
          debugShowCheckedModeBanner: false,
          /// Thiết lập Theme đồng bộ và sử dụng phông chữ Google Fonts Lexend.
          theme: base.currentTheme.copyWith(
            textTheme: GoogleFonts.lexendTextTheme(base.currentTheme.textTheme),
          ),
          /// Kiểm tra trạng thái đăng nhập: Nếu có Token thì vào thẳng Home, ngược lại hiện màn Auth.
          home: base.token != null ? const MainNavigationWrapper() : const AuthScreen(),
        );
      },
    );
  }
}

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});
  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;

  /// Chức năng: Khởi tạo trạng thái cho thanh điều hướng chính.
  @override
  void initState() {
    super.initState();
    /// Đợi khung hình đầu tiên dựng xong rồi mới nạp dữ liệu nền.
    WidgetsBinding.instance.addPostFrameCallback((_) => _initData());
  }

  /// Chức năng: Nạp các dữ liệu cần thiết ban đầu cho người dùng.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  void _initData() {
    final base = Provider.of<BaseProvider>(context, listen: false);
    /// Nếu là người mua (Customer), thực hiện tải danh sách giỏ hàng từ server.
    if (base.token != null && base.user?.role == 'customer') {
      context.read<CartProvider>().fetchCart(base.token!);
    }
  }

  /// Chức năng: Xây dựng cấu trúc điều hướng Tab (Bottom Navigation) linh hoạt theo vai trò.
  @override
  Widget build(BuildContext context) {
    /// Theo dõi thông tin người dùng và chế độ tối để vẽ giao diện phù hợp.
    final user = context.watch<BaseProvider>().user;
    final isDark = context.watch<BaseProvider>().isDarkMode;

    List<Widget> screens = [];
    List<BottomNavigationBarItem> navItems = [];

    /// Logic: Phân quyền hiển thị các màn hình và icon tương ứng với từng chức danh.
    if (user?.role == 'admin') {
      /// Danh sách màn hình dành cho Quản trị viên sàn.
      screens = [const HomeScreen(), const AdminUnifiedManagementScreen(), const ChatListScreen(), const ProfileScreen()];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), activeIcon: Icon(Icons.analytics), label: 'Thống kê'),
        BottomNavigationBarItem(icon: Icon(Icons.storefront_outlined), activeIcon: Icon(Icons.storefront), label: 'Người dùng'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Tin nhắn'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Cá nhân'),
      ];
    } else if (user?.role == 'shop') {
      /// Danh sách màn hình dành cho Chủ gian hàng (Seller).
      screens = [const HomeScreen(), const ShopOrderScreen(), const RevenueScreen(), const ChatListScreen(), const ProfileScreen()];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Shop'),
        BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_outlined), activeIcon: Icon(Icons.shopping_bag), label: 'Đơn hàng'),
        BottomNavigationBarItem(icon: Icon(Icons.payments_outlined), activeIcon: Icon(Icons.payments), label: 'Doanh thu'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Tin nhắn'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Cá nhân'),
      ];
    } else {
      /// Danh sách màn hình dành cho Khách hàng mua máy (Buyer/Guest).
      screens = [const HomeScreen(), const NewsFeedScreen(), const ChatListScreen(), const ProfileScreen()];
      navItems = const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Trang chủ'),
        BottomNavigationBarItem(icon: Icon(Icons.newspaper_outlined), activeIcon: Icon(Icons.newspaper), label: 'Tin tức'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Tin nhắn'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Cá nhân'),
      ];
    }

    return Scaffold(
      /// Sử dụng IndexedStack để giữ nguyên trạng thái cuộn và dữ liệu của từng màn hình khi chuyển Tab.
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        /// Cập nhật chỉ số Tab hiện tại khi người dùng nhấn chọn.
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF0047AB),
        unselectedItemColor: isDark ? Colors.white54 : Colors.grey,
        backgroundColor: Theme.of(context).cardColor,
        items: navItems,
      ),
    );
  }
}