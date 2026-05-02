import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../../providers/base_provider.dart';
import '../admin/admin_revenue_detail_screen.dart';
import '../admin/admin_user_management_screen.dart';
import '../buyer/address_list_screen.dart';
import '../buyer/customer_order_screen.dart';
import '../seller/inventory_screen.dart';
import '../seller/promotion_management_screen.dart';
import './widgets/avatar_handler.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    /// Lắng nghe chọn lọc các thay đổi về giao diện (Dark Mode), cấu hình chữ (Offset) và thông tin người dùng.
    /// Sử dụng context.select giúp tối ưu hiệu năng render, chỉ build lại khi 1 trong 3 thuộc tính này thay đổi.
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);
    final px = context.select<BaseProvider, double>((p) => p.textOffset);
    final user = context.select<BaseProvider, dynamic>((p) => p.user);

    /// Lưu trữ Theme hiện tại vào biến cục bộ để tái sử dụng, tránh truy xuất nhiều lần trong hàm build.
    final theme = Theme.of(context);
    final cardColor = theme.cardColor;

    return Scaffold(
      /// Tự động chuyển đổi màu nền theo chế độ Sáng/Tối.
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Text(
          "CÁ NHÂN",
          style: TextStyle(
            fontSize: 18 + px,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: cardColor,
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: const Color(0xFF0047AB),
            ),
            /// Chức năng: Chuyển đổi qua lại giữa chế độ giao diện sáng và tối.
            onPressed: () => context.read<BaseProvider>().toggleTheme(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        /// Áp dụng hiệu ứng cuộn vật lý mượt mà cho trải nghiệm người dùng Android.
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            /// Hiển thị phần đầu trang gồm Ảnh đại diện, Tên và Vai trò.
            _buildGlobalHeader(user, px, cardColor, isDark),

            const SizedBox(height: 10),

            /// Phân luồng hiển thị Menu chức năng dựa trên vai trò của tài khoản đăng nhập.
            if (user != null) ...[
              if (user.role == 'admin') ..._buildAdminSection(px, cardColor, isDark),
              if (user.role == 'shop') ..._buildShopSection(px, user, cardColor, isDark),
              if (user.role == 'customer') ..._buildBuyerSection(px, cardColor, isDark),
            ] else ...[
              /// Mặc định hiển thị menu người mua nếu không xác định được vai trò.
              ..._buildBuyerSection(px, cardColor, isDark),
            ],

            const SizedBox(height: 10),

            /// Khu vực thiết lập hệ thống.
            _buildSectionTitle("Cài đặt", px, isDark),
            _buildMenuCard(cardColor, [
              _buildMenuTile(
                Icons.text_fields,
                "Chỉnh cỡ chữ: ${px.toInt()} px",
                px,
                isDark,
                    () => _showPixelFontSizeDialog(context),
              ),
            ]),

            /// Nút đăng xuất tài khoản.
            _buildLogoutButton(px),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Xây dựng khu vực tiêu đề hồ sơ (Avatar & Tên).
  /// Tham số đầu vào: [user] dữ liệu người dùng, [px] cỡ chữ, [bgColor] màu nền, [isDark] chế độ tối.
  /// Giá trị trả về: Widget dạng Container.
  Widget _buildGlobalHeader(dynamic user, double px, Color bgColor, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      color: bgColor,
      child: Column(
        children: [
          /// Xử lý hiển thị ảnh đại diện thông qua AvatarHandler.
          AvatarHandler(user: user, px: px),
          const SizedBox(height: 16),
          Text(
            user?.name ?? "Thành viên TSP",
            style: TextStyle(
              fontSize: 20 + px,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          /// Hiển thị nhãn vai trò (Admin/Shop/Buyer).
          _buildRoleChip(user?.role?.toUpperCase() ?? "BUYER", px, isDark),
        ],
      ),
    );
  }

  /// Chức năng: Tạo danh sách các menu dành riêng cho Quản trị viên sàn.
  /// Tham số đầu vào: [px], [cardColor], [isDark].
  /// Giá trị trả về: List<Widget>.
  List<Widget> _buildAdminSection(double px, Color cardColor, bool isDark) => [
    _buildSectionTitle("Hệ thống quản trị", px, isDark),
    _buildMenuCard(cardColor, [
      _buildMenuTile(Icons.admin_panel_settings, "Quản lý tài khoản", px, isDark,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUnifiedManagementScreen()))),
      _buildMenuTile(Icons.analytics_outlined, "Thống kê sàn", px, isDark,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminRevenueDetailScreen()))),
    ]),
  ];

  /// Chức năng: Tạo danh sách các menu quản lý dành cho Chủ cửa hàng.
  /// Tham số đầu vào: [px], [user], [cardColor], [isDark].
  /// Giá trị trả về: List<Widget>.
  List<Widget> _buildShopSection(double px, dynamic user, Color cardColor, bool isDark) => [
    _buildSectionTitle("Quản lý gian hàng", px, isDark),
    _buildMenuCard(cardColor, [
      _buildMenuTile(Icons.inventory_2_outlined, "Kho máy của tôi", px, isDark,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()))),
      _buildMenuTile(Icons.campaign_outlined, "Chương trình khuyến mãi", px, isDark,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PromotionManagementScreen()))),
      _buildMenuTile(Icons.account_balance_wallet_outlined, "Dòng tiền & Ví", px, isDark,
              () => _showComingSoon("Ví Shop")),
    ]),
  ];

  /// Chức năng: Tạo danh sách các menu lịch sử mua hàng và địa chỉ cho Người mua.
  /// Tham số đầu vào: [px], [cardColor], [isDark].
  /// Giá trị trả về: List<Widget>.
  List<Widget> _buildBuyerSection(double px, Color cardColor, bool isDark) => [
    _buildSectionTitle("Mua sắm & Ưu đãi", px, isDark),
    _buildMenuCard(cardColor, [
      _buildMenuTile(Icons.shopping_bag, "Đơn mua của tôi", px, isDark,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerOrderScreen()))),
      _buildMenuTile(Icons.location_on, "Sổ địa chỉ", px, isDark,
              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressListScreen()))),
    ]),
  ];

  /// Chức năng: Tạo khung thẻ (Card) bao bọc danh sách các Menu con.
  /// Tham số đầu vào: [cardColor], [tiles] danh sách các mục menu.
  /// Giá trị trả về: Widget Container có hiệu ứng bóng đổ.
  Widget _buildMenuCard(Color cardColor, List<Widget> tiles) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        )
      ],
    ),
    child: Column(children: tiles),
  );

  /// Chức năng: Xây dựng một hàng menu đơn lẻ (ListTile).
  /// Tham số đầu vào: [icon], [title], [px], [isDark], [onTap].
  /// Giá trị trả về: Widget ListTile chuẩn hóa giao diện.
  Widget _buildMenuTile(IconData icon, String title, double px, bool isDark, VoidCallback onTap) => ListTile(
    leading: Icon(
      icon,
      size: 22 + (px * 0.5),
      color: const Color(0xFF0047AB),
    ),
    title: Text(
      title,
      style: TextStyle(
        fontSize: 15 + px,
        fontWeight: FontWeight.w500,
        color: isDark ? Colors.white : Colors.black,
      ),
    ),
    trailing: const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
    onTap: onTap,
  );

  /// Chức năng: Tạo nhãn tiêu đề cho từng phân đoạn danh mục menu.
  /// Tham số đầu vào: [title], [px], [isDark].
  /// Giá trị trả về: Widget Padding chứa nội dung văn bản.
  Widget _buildSectionTitle(String title, double px, bool isDark) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12 + px,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
    ),
  );

  /// Chức năng: Tạo nhãn (Chip) hiển thị vai trò của người dùng với màu sắc đặc trưng.
  /// Tham số đầu vào: [role], [px], [isDark].
  /// Giá trị trả về: Widget Container được bo tròn.
  Widget _buildRoleChip(String role, double px, bool isDark) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFF0047AB).withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      role,
      style: TextStyle(
        fontSize: 10 + px,
        color: isDark ? const Color(0xFF64B5F6) : const Color(0xFF0047AB),
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  /// Chức năng: Xây dựng nút nhấn đăng xuất với màu sắc cảnh báo.
  /// Tham số đầu vào: [px].
  /// Giá trị trả về: Widget ElevatedButton.
  Widget _buildLogoutButton(double px) => Padding(
    padding: const EdgeInsets.all(20),
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent.withOpacity(0.1),
        foregroundColor: Colors.redAccent,
        elevation: 0,
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: () => context.read<BaseProvider>().logout(),
      child: Text(
        "ĐĂNG XUẤT",
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15 + px),
      ),
    ),
  );

  /// Chức năng: Hiển thị thông báo Toast cho các tính năng chưa hoàn thiện.
  void _showComingSoon(String msg) => Fluttertoast.showToast(msg: "Tính năng '$msg' đang phát triển!");

  /// Chức năng: Hiển thị hộp thoại (Dialog) cho phép người dùng tăng/giảm kích thước chữ toàn ứng dụng.
  /// Tham số đầu vào: [context].
  /// Giá trị trả về: Không có (Mở AlertDialog).
  void _showPixelFontSizeDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (ctx) {
          /// Sử dụng Consumer bên trong build của Dialog để chỉ Rebuild nội dung Dialog khi thay đổi số,
          /// giúp tối ưu hiệu năng và không phải Rebuild lại toàn bộ ProfileScreen phía sau.
          return Consumer<BaseProvider>(
            builder: (context, provider, _) => AlertDialog(
              backgroundColor: Theme.of(ctx).cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("Cỡ chữ Pixel",
                  style: TextStyle(color: provider.isDarkMode ? Colors.white : Colors.black)),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  /// Nút giảm kích thước chữ (Giới hạn tối thiểu là -2).
                  IconButton(
                    icon: const Icon(Icons.remove_circle, color: Colors.blue, size: 35),
                    onPressed: provider.textOffset > -2 ? () => provider.updateTextOffset(provider.textOffset - 1) : null,
                  ),
                  Text(
                      "${provider.textOffset.toInt()} px",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: provider.isDarkMode ? Colors.white : Colors.black,
                      )
                  ),
                  /// Nút tăng kích thước chữ (Giới hạn tối đa là 6).
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue, size: 35),
                    onPressed: provider.textOffset < 6 ? () => provider.updateTextOffset(provider.textOffset + 1) : null,
                  ),
                ],
              ),
            ),
          );
        }
    );
  }
}