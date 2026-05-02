import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/admin_provider.dart';
import '../../../providers/base_provider.dart';

class AdminUnifiedManagementScreen extends StatefulWidget {
  const AdminUnifiedManagementScreen({super.key});

  @override
  State<AdminUnifiedManagementScreen> createState() => _AdminUnifiedManagementScreenState();
}

class _AdminUnifiedManagementScreenState extends State<AdminUnifiedManagementScreen> {

  @override
  void initState() {
    super.initState();
    /// Khởi tạo dữ liệu hệ thống ngay khi màn hình được tạo.
    _refreshSystemData();
  }

  /// Chức năng: Tải lại toàn bộ dữ liệu người dùng và danh sách gian hàng đang chờ duyệt.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  void _refreshSystemData() {
    /// Sử dụng addPostFrameCallback để đảm bảo việc gọi context diễn ra sau khi Widget đã dựng xong.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final base = context.read<BaseProvider>();
      if (base.token != null) {
        /// Thực hiện gọi API lấy danh sách thành viên và các shop đang ở trạng thái chờ (pending).
        context.read<AdminProvider>().fetchAllUsers(base.token!);
        context.read<AdminProvider>().fetchAdminShops(base.token!, 'pending');
      }
    });
  }

  /// Chức năng: Gửi yêu cầu thay đổi trạng thái hoạt động của một gian hàng (Duyệt/Khóa).
  /// Tham số đầu vào: [id] của gian hàng, [status] mục tiêu (approved/blocked), và [token] xác thực.
  /// Giá trị trả về: Future<void>.
  Future<void> _processShopStatus(int id, String status, String token) async {
    final provider = context.read<AdminProvider>();
    final isSuccess = await provider.changeShopStatus(token, id, status);

    /// Nếu cập nhật thành công và màn hình vẫn đang hiển thị, thông báo cho quản trị viên.
    if (isSuccess && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Trạng thái gian hàng: ${status.toUpperCase()} đã cập nhật.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    /// Đăng ký lắng nghe sự thay đổi từ các Provider để tự động cập nhật UI.
    final adminProv = context.watch<AdminProvider>();
    final base = context.watch<BaseProvider>();
    final theme = Theme.of(context);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: const Text("HỆ THỐNG QUẢN TRỊ",
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          centerTitle: true,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: const Color(0xFF0047AB),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            unselectedLabelColor: theme.hintColor,
            tabs: const [
              Tab(text: "THÀNH VIÊN", icon: Icon(Icons.group_outlined)),
              Tab(text: "XÉT DUYỆT", icon: Icon(Icons.storefront_outlined)),
            ],
          ),
          actions: [
            /// Nút làm mới nhanh toàn bộ danh sách quản trị.
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              onPressed: _refreshSystemData,
            )
          ],
        ),
        /// Hiển thị vòng xoay nếu hệ thống đang trong quá trình nạp dữ liệu từ API.
        body: adminProv.isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
          children: [
            _buildAccountSection(adminProv, base.token!),
            _buildShopApprovalSection(adminProv, base.token!),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Xây dựng giao diện danh sách người dùng trong hệ thống.
  /// Tham số đầu vào: [prov] (AdminProvider), [token] xác thực.
  /// Giá trị trả về: Widget dạng danh sách cuộn.
  Widget _buildAccountSection(AdminProvider prov, String token) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: prov.users.length,
      itemBuilder: (ctx, i) {
        final user = prov.users[i];
        return Card(
          color: Theme.of(context).cardColor,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${user.email}\nVai trò: ${user.role.toUpperCase()}"),
            trailing: Switch(
              /// Switch điều khiển trạng thái Kích hoạt/Khóa của tài khoản.
              value: user.status == 'active',
              activeColor: Colors.green,
              onChanged: (statusValue) async {
                final targetStatus = statusValue ? 'active' : 'blocked';
                final isOk = await prov.updateUserAccount(token, user.id, status: targetStatus);
                /// Nếu cập nhật trạng thái thành công, tải lại danh sách để đồng bộ UI.
                if (isOk) prov.fetchAllUsers(token);
              },
            ),
            /// Cho phép Admin nhấn giữ lâu để mở hộp thoại thay đổi quyền hạn.
            onLongPress: () => _displayRoleEditor(user, token),
          ),
        );
      },
    );
  }

  /// Chức năng: Xây dựng giao diện danh sách các cửa hàng đang chờ được Admin duyệt.
  /// Tham số đầu vào: [prov] (AdminProvider), [token] xác thực.
  /// Giá trị trả về: Widget hiển thị danh sách shop hoặc thông báo trống.
  Widget _buildShopApprovalSection(AdminProvider prov, String token) {
    /// Kiểm tra nếu không có yêu cầu nào thì hiển thị trạng thái trống.
    if (prov.shops.isEmpty) {
      return const Center(child: Text("Hiện không có yêu cầu nào chờ xử lý."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: prov.shops.length,
      itemBuilder: (ctx, i) {
        final shop = prov.shops[i];
        return Card(
          color: Theme.of(context).cardColor,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.1),
              backgroundImage: (shop.avatar != null) ? NetworkImage(shop.avatar!) : null,
              child: (shop.avatar == null) ? const Icon(Icons.store) : null,
            ),
            title: Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Kho: ${shop.warehouseAddress}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                /// Nút phê duyệt gian hàng hoạt động.
                IconButton(
                  icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                  onPressed: () => _processShopStatus(shop.id, 'approved', token),
                ),
                /// Nút từ chối hoặc khóa gian hàng.
                IconButton(
                  icon: const Icon(Icons.highlight_off_rounded, color: Colors.red),
                  onPressed: () => _processShopStatus(shop.id, 'blocked', token),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Chức năng: Hiển thị hộp thoại lựa chọn vai trò (Customer/Shop/Admin) cho thành viên.
  /// Tham số đầu vào: [user] đối tượng người dùng cần sửa, [token] xác thực.
  /// Giá trị trả về: Không có.
  void _displayRoleEditor(dynamic user, String token) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        title: const Text("Điều chỉnh quyền hạn"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          /// Duyệt qua danh sách các quyền hạn có sẵn trong hệ thống Phone Market.
          children: ['customer', 'shop', 'admin'].map((roleKey) => ListTile(
            title: Text(roleKey.toUpperCase(), style: const TextStyle(fontSize: 14)),
            trailing: const Icon(Icons.chevron_right, size: 16),
            onTap: () async {
              Navigator.pop(ctx);
              /// Gửi yêu cầu cập nhật vai trò mới lên server.
              final isOk = await context.read<AdminProvider>().updateUserAccount(token, user.id, role: roleKey);
              /// Làm mới danh sách sau khi phân quyền lại.
              if (isOk) context.read<AdminProvider>().fetchAllUsers(token);
            },
          )).toList(),
        ),
      ),
    );
  }
}