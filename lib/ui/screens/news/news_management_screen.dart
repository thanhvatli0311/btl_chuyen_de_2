import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../data/models/news_model.dart';
import '../../../providers/base_provider.dart';
import '../../../core/utils/image_helper.dart';
import 'edit_news_screen.dart';
import 'news_detail_screen.dart';

class NewsManagementScreen extends StatefulWidget {
  const NewsManagementScreen({super.key});
  @override
  State<NewsManagementScreen> createState() => _NewsManagementScreenState();
}

class _NewsManagementScreenState extends State<NewsManagementScreen> {
  List<dynamic> _newsList = [];
  bool _isLoading = true;

  /// Bộ định dạng ngày giờ tĩnh dùng chung cho toàn màn hình.
  /// Khai báo static final giúp tối ưu tài nguyên, khởi tạo duy nhất 1 lần để dùng cho mọi thẻ bài viết.
  static final DateFormat _dateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    /// Khởi chạy hàm nạp dữ liệu ngay khi màn hình vừa được khởi tạo.
    _fetchNews();
  }

  /// Chức năng: Gọi API lấy danh sách các bản tin dựa trên quyền hạn của người dùng hiện tại.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void> xử lý bất đồng bộ.
  Future<void> _fetchNews() async {
    try {
      final base = context.read<BaseProvider>();
      final token = base.token;
      /// Kiểm tra token xác thực trước khi gửi yêu cầu lên máy chủ.
      if (token == null) return;

      final data = await base.apiService.getNewsManagement(token);

      /// Đảm bảo widget vẫn còn tồn tại trong cây thư mục (mounted) trước khi cập nhật trạng thái UI.
      if (mounted) {
        setState(() {
          _newsList = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      /// Xử lý lỗi nếu có sự cố mạng hoặc lỗi server và tắt trạng thái chờ.
      if (mounted) setState(() => _isLoading = false);
      debugPrint("❌ Lỗi fetch news management: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    /// Sử dụng context.select để chỉ theo dõi và phản hồi khi các giá trị cần thiết thay đổi.
    final isAdmin = context.select<BaseProvider, bool>((p) => p.user?.role == 'admin');
    final px = context.select<BaseProvider, double>((p) => p.textOffset);
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);
    final token = context.select<BaseProvider, String?>((p) => p.token);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("QUẢN LÝ BẢN TIN",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 + px)),
        centerTitle: true,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        /// Tính năng kéo từ trên xuống để cập nhật lại danh sách bài viết.
        onRefresh: _fetchNews,
        child: _newsList.isEmpty
            ? Center(child: Text("Chưa có bài viết nào.",
            style: TextStyle(fontSize: 14 + px, color: Colors.grey)))
            : ListView.builder(
          /// cacheExtent giúp chuẩn bị sẵn dữ liệu bên dưới màn hình, tối ưu cho trải nghiệm cuộn nhanh.
          cacheExtent: 500,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: _newsList.length,
          itemBuilder: (ctx, i) => _buildNewsManageCard(
              _newsList[i], isAdmin, px, isDark, token ?? ""
          ),
        ),
      ),
    );
  }

  /// Chức năng: Tạo giao diện thẻ quản lý cho từng bản tin đơn lẻ.
  /// Tham số đầu vào: [item] dữ liệu bản tin, [isAdmin] kiểm tra quyền, [px] cỡ chữ, [isDark] chế độ tối, [token] xác thực.
  /// Giá trị trả về: Widget dạng thẻ có thể tương tác nhấn vào.
  Widget _buildNewsManageCard(dynamic item, bool isAdmin, double px, bool isDark, String token) {
    /// Giải mã chuỗi JSON danh sách hình ảnh từ máy chủ trả về.
    List<dynamic> imageList = [];
    if (item['images'] != null) {
      try {
        imageList = jsonDecode(item['images']);
      } catch (e) {
        debugPrint("Lỗi parse ảnh news: $e");
      }
    }

    /// Lấy tấm ảnh đầu tiên trong danh sách để làm ảnh đại diện cho thẻ bài viết.
    final String? firstImage = imageList.isNotEmpty ? imageList[0] : null;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => NewsDetailScreen(newsId: item['id'])
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4)
            )
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: firstImage != null
                        ? ImageHelper.load(firstImage, width: 80, height: 80, fit: BoxFit.cover)
                        : Container(
                        width: 80, height: 80,
                        color: isDark ? Colors.white10 : Colors.grey[200],
                        child: const Icon(Icons.image_not_supported, color: Colors.grey)
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['title'] ?? "",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.storefront, size: 14, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(item['shop']?['name'] ?? "Sàn TSP",
                                style: TextStyle(color: Colors.blue, fontSize: 12 + px)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          /// Hiển thị thời gian đăng bài được định dạng qua biến tĩnh đã khai báo.
                          "Đăng lúc: ${_dateTimeFormatter.format(DateTime.parse(item['created_at']))}",
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  /// Hiển thị số lượng tương tác (Like, Comment) của bài viết.
                  Row(
                    children: [
                      _buildStatItem(Icons.favorite_border, item['likes_count']?.toString() ?? "0", Colors.red),
                      const SizedBox(width: 16),
                      _buildStatItem(Icons.chat_bubble_outline, item['comments_count']?.toString() ?? "0", Colors.orange),
                    ],
                  ),
                  /// Nhóm các nút chức năng (Sửa/Xóa) tùy theo vai trò.
                  Row(
                    children: [
                      /// Chỉ chủ Shop mới thấy nút Chỉnh sửa bài viết.
                      if (!isAdmin)
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: Colors.blue),
                          onPressed: () {
                            final postModel = NewsPostModel.fromJson(item as Map<String, dynamic>);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => EditNewsScreen(news: postModel)),
                            ).then((_) => _fetchNews());
                          },
                        ),
                      /// Cả Admin và Shop đều có thể thực hiện xóa bài.
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDelete(item['id'], token),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Tạo ra các khối hiển thị số liệu thống kê (Like/Comment).
  /// Tham số đầu vào: [icon] biểu tượng, [value] giá trị số, [color] màu chủ đạo.
  /// Giá trị trả về: Widget dạng hàng (Row).
  Widget _buildStatItem(IconData icon, String value, Color color) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 4),
      Text(value, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
    ]);
  }

  /// Chức năng: Hiển thị hộp thoại cảnh báo trước khi tiến hành xóa vĩnh viễn bài viết.
  /// Tham số đầu vào: [id] của bài viết, [token] xác thực.
  /// Giá trị trả về: Không có (Mở AlertDialog).
  void _confirmDelete(int id, String token) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Xác nhận xóa bài?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Dữ liệu và ảnh bài viết sẽ bị xóa vĩnh viễn khỏi hệ thống."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0),
            onPressed: () async {
              final api = context.read<BaseProvider>().apiService;
              final res = await api.deleteNews(id, token);

              /// Nếu xóa thành công và context của Dialog vẫn tồn tại, thông báo và tải lại danh sách.
              if (res.data['success'] && ctx.mounted) {
                Fluttertoast.showToast(msg: "Đã xóa!");
                Navigator.pop(ctx);
                _fetchNews();
              }
            },
            child: const Text("XÓA NGAY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}