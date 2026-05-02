import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../data/models/category_brand_model.dart';
import '../../../data/models/user_model.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../data/models/phone_model.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/notification_provider.dart'; // Nạp Provider thông báo
import '../../../core/utils/image_helper.dart';

import '../admin/brand_management_screen.dart';
import '../news/news_feed_screen.dart';
import '../news/news_management_screen.dart';
import '../seller/inventory_screen.dart';
import '../seller/add_phone_screen.dart';
import '../seller/promotion_management_screen.dart';
import '../seller/seller_policy_screen.dart';
import '../admin/send_broadcast_screen.dart';
import '../news/create_news_screen.dart';
import '../notification/notification_screen.dart'; // Nạp màn hình thông báo
import 'phone_detail_screen.dart';
import 'cart_screen.dart';
import '../admin/admin_revenue_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<PhoneModel> _phones = [];
  List<BrandModel> _brands = [];
  bool _isLoading = true;
  int? _selectedBrandId;
  String? _selectedSort;

  /// Bộ định dạng tiền tệ Việt Nam dùng chung cho toàn màn hình.
  /// Sử dụng biến tĩnh để tránh việc khởi tạo lại đối tượng định dạng trong mỗi lần Rebuild.
  final NumberFormat _currencyFormatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    /// Gọi hàm nạp dữ liệu ngay sau khi khung hình đầu tiên được dựng xong.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAllInitialData());
  }

  @override
  void dispose() {
    /// Chức năng: Giải phóng bộ nhớ của bộ điều khiển tìm kiếm.
    /// Tham số đầu vào: Không có.
    /// Giá trị trả về: Không có.
    _searchController.dispose();
    super.dispose();
  }

  /// Chức năng: Thực hiện nạp đồng thời danh sách điện thoại và danh sách hãng sản xuất.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void>.
  Future<void> _loadAllInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      /// Sử dụng Future.wait để chạy song song các yêu cầu mạng, giúp giảm thời gian chờ đợi.
      await Future.wait([
        _fetchData(isInitial: true),
        _loadBrands(),
      ]);
    } catch (e) {
      debugPrint("❌ Lỗi nạp dữ liệu đầu: $e");
    } finally {
      /// Đảm bảo trạng thái tải được tắt sau khi các yêu cầu hoàn tất.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Chức năng: Tải danh sách thương hiệu (Brand) từ máy chủ.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void>.
  Future<void> _loadBrands() async {
    try {
      final List<BrandModel> data = await context.read<BaseProvider>().apiService.getBrands();
      if (mounted) _brands = data;
    } catch (e) {
      debugPrint("❌ Lỗi lấy hãng: $e");
    }
  }

  /// Chức năng: Tải danh sách điện thoại dựa trên các tham số tìm kiếm, lọc theo hãng và sắp xếp.
  /// Tham số đầu vào: [isInitial] - Cờ xác định đây có phải là lần nạp dữ liệu đầu tiên không.
  /// Giá trị trả về: Future<void>.
  Future<void> _fetchData({bool isInitial = false}) async {
    /// Nếu không phải nạp lần đầu, hiển thị vòng xoay loading khi người dùng thay đổi bộ lọc.
    if (!isInitial) setState(() => _isLoading = true);

    try {
      final base = context.read<BaseProvider>();
      final admin = context.read<AdminProvider>();

      /// Gọi API lấy danh sách máy kèm theo các điều kiện lọc hiện tại.
      final data = await base.apiService.getPhones(
        query: _searchController.text.trim(),
        brandId: _selectedBrandId,
        sortBy: _selectedSort,
      );

      /// Nếu người dùng là quản trị viên, nạp thêm dữ liệu thống kê cho Dashboard.
      if (base.user?.role == 'admin' && base.token != null) {
        await admin.fetchDashboardStats(base.token!);
      }

      if (mounted) {
        setState(() {
          _phones = data;
          if (!isInitial) _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !isInitial) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    /// Lắng nghe các thay đổi về cấu hình người dùng, giao diện và cỡ chữ từ Provider.
    final base = context.watch<BaseProvider>();
    final user = base.user;
    final isDark = base.isDarkMode;
    final px = base.textOffset;

    /// Phân luồng giao diện dựa trên vai trò của tài khoản (Admin, Shop, hoặc Người mua).
    if (user?.role == 'admin') return _buildAdminDashboard();
    if (user?.role == 'shop') return _buildShopDashboard(user);

    return _buildBuyerHome(user, px, isDark);
  }

  /// Chức năng: Xây dựng giao diện trang chủ cho người mua (Buyer).
  /// Tham số đầu vào: [user], [px], [isDark].
  /// Giá trị trả về: Widget dạng Scaffold.
  Widget _buildBuyerHome(UserModel? user, double px, bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: _buildSearchBar(),
        /// CHỈNH SỬA: Thêm nút thông báo và giỏ hàng cho khách hàng.
        actions: [
          _buildNotificationBadge(),
          _buildCartBadge(),
          const SizedBox(width: 8)
        ],
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0.5,
      ),
      body: Column(
        children: [
          /// Hiển thị cảnh báo nếu tài khoản Shop đang trong trạng thái chờ duyệt.
          if (user?.shop?.status == 'pending') _buildPendingBanner(),
          _buildNewsBanner(px, isDark),
          _buildBrandFilterPanel(px, isDark),
          _buildSortPanel(px, isDark),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchData,
              child: _isLoading && _phones.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _phones.isEmpty
                  ? _buildEmptyState(px)
                  : GridView.builder(
                cacheExtent: 500,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: _phones.length,
                itemBuilder: (context, i) => _buildPhoneCard(_phones[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Chức năng: Xây dựng thanh trượt danh sách các hãng sản xuất để lọc máy.
  /// Tham số đầu vào: [px], [isDark].
  /// Giá trị trả về: Widget chứa danh sách các nút bấm hãng.
  Widget _buildBrandFilterPanel(double px, bool isDark) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _brands.length + 1,
        itemBuilder: (ctx, i) {
          /// Mục đầu tiên là "Xem tất cả" để xóa bộ lọc hãng.
          final bool isAll = i == 0;
          final b = isAll ? null : _brands[i - 1];
          final bool isSelected = _selectedBrandId == b?.id;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: () {
                if (_selectedBrandId == b?.id) return;
                setState(() => _selectedBrandId = b?.id);
                _fetchData();
              },
              borderRadius: BorderRadius.circular(25),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isAll ? const Color(0xFF0D9488) : (isDark ? Colors.white : Colors.black))
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: isSelected ? Colors.transparent : (isDark ? Colors.white24 : Colors.grey[300]!),
                  ),
                ),
                child: Center(
                  child: Text(
                    isAll ? "Xem tất cả" : b!.name,
                    style: TextStyle(
                      fontSize: 13 + px,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Chức năng: Xây dựng thanh lựa chọn các tiêu chí sắp xếp sản phẩm.
  /// Tham số đầu vào: [px], [isDark].
  /// Giá trị trả về: Widget dạng hàng (Row) nằm trong SingleChildScrollView.
  Widget _buildSortPanel(double px, bool isDark) {
    const sorts = [
      {'id': 'discount', 'label': 'Giảm sâu nhất', 'icon': Icons.local_offer_outlined},
      {'id': 'latest', 'label': 'Mới lên kệ', 'icon': Icons.fiber_new_outlined},
      {'id': 'price_desc', 'label': 'Giá Cao - Thấp', 'icon': Icons.trending_up},
      {'id': 'price_asc', 'label': 'Giá Thấp - Cao', 'icon': Icons.trending_down},
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: sorts.map((s) {
          final bool isSelected = _selectedSort == s['id'];
          return GestureDetector(
            onTap: () {
              setState(() => _selectedSort = isSelected ? null : s['id'] as String);
              _fetchData();
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(s['icon'] as IconData, size: 16, color: isSelected ? const Color(0xFF0D9488) : Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        s['label'] as String,
                        style: TextStyle(
                          fontSize: 12 + px,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? const Color(0xFF0D9488) : (isDark ? Colors.white54 : Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                  /// Hiển thị đường kẻ gạch chân cho tiêu chí đang được chọn.
                  if (isSelected)
                    Container(height: 2, width: 30, color: const Color(0xFF0047AB), margin: const EdgeInsets.only(top: 4))
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Chức năng: Hiển thị thông báo khi không tìm thấy sản phẩm nào khớp với bộ lọc.
  Widget _buildEmptyState(double px) => Center(child: Text("Không có máy nào phù hợp.", style: TextStyle(fontSize: 14 + px, color: Colors.grey)));

  /// Chức năng: Tạo ô nhập liệu tìm kiếm ở trên thanh ứng dụng.
  Widget _buildSearchBar() => Container(
    height: 40, padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
    child: TextField(
      controller: _searchController,
      decoration: const InputDecoration(hintText: "Tìm máy...", prefixIcon: Icon(Icons.search, size: 20), border: InputBorder.none),
      onSubmitted: (_) => _fetchData(),
    ),
  );

  /// Chức năng: Tạo biểu tượng giỏ hàng kèm theo nhãn hiển thị số lượng món hàng hiện có.
  Widget _buildCartBadge() => Consumer<CartProvider>(
    builder: (context, cart, _) => Stack(
      alignment: Alignment.center,
      children: [
        IconButton(icon: const Icon(Icons.shopping_cart_outlined), onPressed: () => _nav(const CartScreen())),
        if (cart.items.isNotEmpty)
          Positioned(
              right: 6,
              top: 6,
              child: CircleAvatar(
                  radius: 8,
                  backgroundColor: Colors.red,
                  child: Text('${cart.items.length}', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))
              )
          ),
      ],
    ),
  );

  /// Chức năng: Xây dựng biểu tượng thông báo kèm theo chấm đỏ hiển thị số lượng tin chưa đọc.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Widget dạng Stack bọc trong Consumer để tự động cập nhật trạng thái.
  Widget _buildNotificationBadge() => Consumer<NotificationProvider>(
    builder: (context, noti, _) => Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () => _nav(const NotificationScreen())
        ),
        /// Chỉ hiển thị chấm đỏ khi có ít nhất một thông báo chưa đọc.
        if (noti.unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5), // Viền trắng giúp nổi bật trên AppBar
              ),
              constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
              child: Text(
                '${noti.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    ),
  );

  /// Chức năng: Xây dựng giao diện thẻ hiển thị thông tin tóm tắt của một chiếc điện thoại.
  /// Tham số đầu vào: [p] - Đối tượng Model chứa dữ liệu điện thoại.
  /// Giá trị trả về: Widget dạng GestureDetector bọc lấy Stack và Column.
  Widget _buildPhoneCard(PhoneModel p) {
    /// Tính toán số tiền tiết kiệm và nhãn % giảm giá để hiển thị lên thẻ.
    final double savingValue = (p.discountPrice != null && p.price > 0) ? p.price - p.discountPrice! : 0;
    String discountLabel = "";

    if (savingValue > 0) {
      double percent = (savingValue / p.price) * 100;
      discountLabel = percent >= 1 ? "-${percent.toInt()}%" : "-${(savingValue / 1000).toInt()}k";
    }

    return GestureDetector(
      onTap: () => _nav(PhoneDetailScreen(slug: p.slug)),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    child: ImageHelper.load(p.thumbnailUrl, fit: BoxFit.contain),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      /// Hiển thị giá khuyến mãi (nếu có) hoặc giá gốc.
                      Text(
                        _currencyFormatter.format(p.discountPrice ?? p.price),
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      /// Nếu đang giảm giá, hiển thị thêm giá gốc bị gạch ngang.
                      if (p.discountPrice != null)
                        Text(
                          _currencyFormatter.format(p.price),
                          style: const TextStyle(color: Colors.grey, fontSize: 10, decoration: TextDecoration.lineThrough),
                        ),
                    ],
                  ),
                )
              ],
            ),
            /// Hiển thị huy hiệu (badge) giảm giá ở góc trái trên cùng nếu có khuyến mãi.
            if (discountLabel.isNotEmpty)
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                  child: Text(discountLabel, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Hiển thị biểu ngữ thông báo shop đang chờ duyệt.
  Widget _buildPendingBanner() => Container(
    margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.withOpacity(0.3))),
    child: const Text("Yêu cầu mở Shop đang chờ xét duyệt!", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
  );

  /// Chức năng: Xây dựng giao diện bảng điều khiển dành riêng cho quản trị viên sàn (Admin).
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Widget dạng Scaffold.
  Widget _buildAdminDashboard() {
    final stats = context.watch<AdminProvider>().stats;
    return Scaffold(
      appBar: AppBar(title: const Text("HỆ THỐNG QUẢN TRỊ")),
      body: RefreshIndicator(
        onRefresh: _fetchData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            InkWell(
              onTap: () => _nav(const AdminRevenueDetailScreen()),
              child: Card(
                color: const Color(0xFF0047AB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("TỔNG GIÁ TRỊ GIAO DỊCH", style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                      Text(_currencyFormatter.format(stats?.totalShopRevenue ?? 0), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 16), const Divider(color: Colors.white24), const SizedBox(height: 16),
                      const Text("DOANH THU VẬN HÀNH HỆ THỐNG", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                      Text(_currencyFormatter.format(stats?.totalPlatformRevenue ?? 0), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _menuCard([
              _menuItem(Icons.branding_watermark_outlined, "Quản lý Hãng", "Thêm, sửa, xóa thương hiệu", () => _nav(const BrandManagementScreen())),
              _menuItem(Icons.campaign, "Phát thông báo", "Gửi tin toàn sàn", () => _nav(const SendBroadcastScreen())),
              _menuItem(Icons.post_add, "Đăng tin/Bản tin", "Tạo bài viết mới", () => _nav(const CreateNewsScreen())),
              _menuItem(Icons.auto_stories_outlined, "Quản lý tin tức", "Xóa/Duyệt bài sàn", () => _nav(const NewsManagementScreen())),
              _menuItem(Icons.settings, "Cấu hình hệ thống", "Phí sàn, Tiền cọc", () {}),
            ]),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Xây dựng giao diện bảng điều khiển dành cho chủ cửa hàng (Shop).
  /// Tham số đầu vào: [user].
  /// Giá trị trả về: Widget dạng Scaffold.
  Widget _buildShopDashboard(UserModel? user) {
    return Scaffold(
      appBar: AppBar(title: Text("SHOP: ${user?.name}")),
      body: RefreshIndicator(
        onRefresh: () async => await context.read<BaseProvider>().getProfile(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Theme.of(context).primaryColor, Colors.blue.shade400]),
                    borderRadius: BorderRadius.circular(20)
                ),
                child: Column(
                  children: [
                    const Text("GIÁ TRỊ SHOP", style: TextStyle(color: Colors.white70)),
                    Text(_currencyFormatter.format(user?.shop?.balance ?? 0), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _menuCard([
              _menuItem(Icons.add_box_outlined, "Đăng bán máy mới", "Thêm sản phẩm", () => _nav(const AddPhoneScreen())),
              _menuItem(Icons.local_offer_outlined, "Quản lý khuyến mãi", "Giảm giá sản phẩm",() => _nav(const PromotionManagementScreen())),
              _menuItem(Icons.newspaper_outlined, "Đăng tin mới", "Chia sẻ tin công nghệ", () => _nav(const CreateNewsScreen())),
              _menuItem(Icons.edit_note_outlined, "Bài viết của tôi", "Chỉnh sửa tin đã đăng", () => _nav(const NewsManagementScreen())),
              _menuItem(Icons.inventory_2_outlined, "Kho máy", "Cập nhật tồn kho", () => _nav(const InventoryScreen())),
              _menuItem(Icons.policy_outlined, "Chính sách", "Quy định người bán", () => _nav(const SellerPolicyScreen())),
            ]),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Tạo khung chứa danh sách các menu chức năng.
  Widget _menuCard(List<Widget> children) => Card(child: Column(children: children));

  /// Chức năng: Xây dựng một hàng menu đơn lẻ.
  Widget _menuItem(IconData icon, String t, String s, VoidCallback onTap) => ListTile(leading: Icon(icon, color: const Color(0xFF0047AB)), title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(s), trailing: const Icon(Icons.chevron_right), onTap: onTap);

  /// Chức năng: Thực hiện điều hướng sang màn hình mới.
  void _nav(Widget s) => Navigator.push(context, MaterialPageRoute(builder: (_) => s));

  /// Chức năng: Hiển thị biểu ngữ tin tức công nghệ với hiệu ứng dải màu (Gradient).
  /// Tham số đầu vào: [px], [isDark].
  /// Giá trị trả về: Widget dạng Padding chứa InkWell.
  Widget _buildNewsBanner(double px, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: InkWell(
        onTap: () => _nav(const NewsFeedScreen()),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                  : [const Color(0xFF0047AB), const Color(0xFF00BFFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Tin mới nhất", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14 + px, letterSpacing: 0.5)),
                    Text("Cập nhật xu hướng và giá máy mới nhất", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11 + px)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}