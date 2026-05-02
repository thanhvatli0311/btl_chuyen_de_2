import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../providers/base_provider.dart';
import '../../../data/repositories/api_service.dart';
import '../../../data/models/phone_model.dart';
import '../../../core/utils/image_helper.dart';
import 'add_phone_screen.dart';
import '../buyer/phone_detail_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  /// Bộ định dạng tiền tệ Việt Nam dùng chung cho toàn màn hình.
  /// Khai báo tĩnh (static) để khởi tạo một lần duy nhất, tránh tốn tài nguyên khi build lại danh sách.
  static final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  /// Danh sách chứa các máy điện thoại thuộc sở hữu của shop.
  List<PhoneModel> _myInventory = [];
  /// Trạng thái đang tải dữ liệu để hiển thị vòng xoay loading.
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    /// Chức năng: Đăng ký nạp dữ liệu ngay khi màn hình vừa được dựng xong.
    /// Logic: Sử dụng addPostFrameCallback để đảm bảo Context đã sẵn sàng hoàn toàn.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInventory());
  }

  /// Chức năng: Tải danh sách điện thoại của Shop hiện tại từ Server.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void> hỗ trợ xử lý bất đồng bộ.
  Future<void> _loadInventory() async {
    if (!mounted) return;

    /// Nếu kho hàng đang trống thì mới hiện loading toàn màn hình, tránh gây khó chịu khi refresh.
    if (_myInventory.isEmpty) {
      setState(() => _isLoading = true);
    }

    final base = context.read<BaseProvider>();
    final token = base.token;

    /// Kiểm tra nếu chưa đăng nhập thì dừng xử lý để tránh lỗi request.
    if (token == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      /// Thực hiện gọi API lấy danh sách máy của Shop thông qua ApiService.
      final api = base.apiService;
      final data = await api.getMyShopPhones(token);

      if (mounted) {
        setState(() {
          _myInventory = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      /// Xử lý lỗi nếu kết nối thất bại và thông báo cho người dùng.
      if (mounted) {
        setState(() => _isLoading = false);
        Fluttertoast.showToast(msg: "Không thể nạp danh sách máy.");
      }
    }
  }

  /// Chức năng: Xây dựng giao diện tổng thể của màn hình kho hàng.
  @override
  Widget build(BuildContext context) {
    /// Sử dụng context.select để chỉ lắng nghe những thuộc tính cần thiết, tối ưu hiệu năng render.
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);
    final px = context.select<BaseProvider, double>((p) => p.textOffset);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
        title: Text("KHO MÁY CỦA BẠN",
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18 + px,
                color: isDark ? Colors.white : Colors.black87,
                letterSpacing: -0.5)),
        actions: [
          IconButton(
              icon: Icon(Icons.refresh_rounded, color: isDark ? Colors.blueAccent : const Color(0xFF0047AB)),
              onPressed: _loadInventory
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : RefreshIndicator(
        onRefresh: _loadInventory,
        child: _myInventory.isEmpty
            ? _buildEmptyState(px, isDark)
            : ListView.builder(
          /// cacheExtent giúp chuẩn bị sẵn các phần tử bên dưới màn hình để cuộn mượt hơn.
          cacheExtent: 500,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: _myInventory.length,
          itemBuilder: (context, index) {
            return _buildInventoryCard(_myInventory[index], px, theme, isDark);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        elevation: 8,
        highlightElevation: 12,
        backgroundColor: const Color(0xFF0047AB),
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPhoneScreen())
        ).then((value) {
          /// Nếu sau khi quay về từ màn hình thêm máy có kết quả thành công thì nạp lại kho.
          if (value == true) _loadInventory();
        }),
        icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
        label: Text("ĐĂNG MÁY MỚI",
            style: TextStyle(color: Colors.white, fontSize: 13 + px, fontWeight: FontWeight.w900)),
      ),
    );
  }

  /// Chức năng: Xây dựng thẻ (Card) hiển thị chi tiết thông tin một chiếc điện thoại trong kho.
  /// Tham số đầu vào: [phone] model dữ liệu, [px] cỡ chữ offset, [theme] chủ đề ứng dụng, [isDark] chế độ tối.
  /// Giá trị trả về: Widget dạng thẻ chứa ảnh và thông tin máy.
  Widget _buildInventoryCard(PhoneModel phone, double px, ThemeData theme, bool isDark) {
    return Container(
      key: ValueKey(phone.id),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: isDark ? Colors.black45 : Colors.black.withOpacity(0.03),
              blurRadius: 25,
              offset: const Offset(0, 12))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => PhoneDetailScreen(slug: phone.slug))
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      /// Hero Widget tạo hiệu ứng chuyển cảnh ảnh sản phẩm mượt mà sang trang chi tiết.
                      Hero(
                          tag: 'inventory-${phone.id}',
                          child: ImageHelper.load(phone.thumbnailUrl, width: 90, height: 90, borderRadius: 20)
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(phone.title,
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15 + px,
                                    color: isDark ? Colors.white : Colors.black87),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(_currencyFormat.format(phone.price),
                                style: TextStyle(
                                    color: const Color(0xFF0047AB),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 17 + px)),
                            const SizedBox(height: 8),
                            _buildInfoRow(Icons.layers_outlined, "Tồn kho: ${phone.stock}", px, isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                /// Thanh trạng thái và bộ nút thao tác nhanh phía dưới mỗi thẻ máy.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF8F9FA),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildStatusBadge(phone.status, px, isDark),
                      Row(
                        children: [
                          _buildSmallActionBtn(
                            icon: Icons.edit_rounded,
                            label: "Sửa",
                            color: Colors.blueGrey,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AddPhoneScreen(phone: phone)),
                            ).then((value) => value == true ? _loadInventory() : null),
                          ),
                          const SizedBox(width: 8),
                          _buildSmallActionBtn(
                            icon: Icons.delete_outline_rounded,
                            label: "Xóa",
                            color: Colors.redAccent,
                            onTap: () => _confirmDelete(phone.id, px, isDark, theme),
                          ),
                        ],
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Chức năng: Tạo một hàng hiển thị thông tin kèm biểu tượng nhỏ.
  /// Tham số đầu vào: [icon] biểu tượng, [text] nội dung hiển thị, [px], [isDark].
  Widget _buildInfoRow(IconData icon, String text, double px, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.white38 : Colors.grey[400]),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontSize: 12 + px, color: isDark ? Colors.white60 : Colors.grey[600])),
      ],
    );
  }

  /// Chức năng: Xây dựng nút bấm hành động thu nhỏ (Sửa/Xóa) cho từng thẻ sản phẩm.
  /// Tham số đầu vào: [icon], [label] nhãn, [color] màu sắc, [onTap] hàm xử lý khi nhấn.
  Widget _buildSmallActionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Hiển thị nhãn trạng thái phê duyệt của máy (Đang bán hoặc Chờ duyệt).
  /// Tham số đầu vào: [status] chuỗi trạng thái, [px], [isDark].
  Widget _buildStatusBadge(String status, double px, bool isDark) {
    final bool isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: (isActive ? Colors.green : Colors.orange).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12)
      ),
      child: Text(isActive ? "ĐANG MỞ BÁN" : "CHỜ DUYỆT",
          style: TextStyle(
              color: isActive ? Colors.green : Colors.orange,
              fontSize: 10 + px,
              fontWeight: FontWeight.w900)),
    );
  }

  /// Chức năng: Hiển thị giao diện thông báo khi kho hàng hoàn toàn không có máy nào.
  /// Tham số đầu vào: [px], [isDark].
  Widget _buildEmptyState(double px, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.style_rounded, size: 80, color: isDark ? Colors.white10 : Colors.grey[200]),
          const SizedBox(height: 20),
          Text("Chưa có máy nào",
              style: TextStyle(fontSize: 18 + px, fontWeight: FontWeight.w800, color: isDark ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
  }

  /// Chức năng: Hiển thị hộp thoại yêu cầu xác nhận trước khi thực hiện xóa vĩnh viễn sản phẩm.
  /// Tham số đầu vào: [id] mã sản phẩm cần xóa, [px], [isDark], [theme].
  /// Giá trị trả về: Không có (Thực hiện điều hướng/gọi API).
  void _confirmDelete(int id, double px, bool isDark, ThemeData theme) {
    final token = context.read<BaseProvider>().token;
    if (token == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text("Xác nhận xóa?", style: TextStyle(fontWeight: FontWeight.w900)),
        content: const Text("Máy sẽ bị gỡ khỏi sàn vĩnh viễn."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("QUAY LẠI")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: () async {
              final api = context.read<BaseProvider>().apiService;
              final res = await api.deletePhone(id, token);

              /// Kiểm tra kết quả trả về từ server để thông báo cho người dùng.
              if (res.data['success'] == true) {
                Fluttertoast.showToast(msg: "Đã gỡ máy khỏi sàn thành công");
                _loadInventory();
              } else {
                Fluttertoast.showToast(msg: res.data['message'] ?? "Không thể xóa máy này!");
              }

              /// Kiểm tra mounted để đảm bảo widget vẫn còn tồn tại trước khi tắt Dialog, tránh lỗi văng app.
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text("XÁC NHẬN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}