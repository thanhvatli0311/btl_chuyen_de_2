import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import '../../../data/models/phone_model.dart';
import '../../../providers/base_provider.dart';
import '../../../core/utils/image_helper.dart';
import '../buyer/phone_detail_screen.dart';

class NewsDetailScreen extends StatefulWidget {
  final int newsId;
  const NewsDetailScreen({super.key, required this.newsId});

  @override
  State<NewsDetailScreen> createState() => _NewsDetailScreenState();
}

class _NewsDetailScreenState extends State<NewsDetailScreen> {
  Map<String, dynamic>? _news;
  List<PhoneModel> _linkedProducts = [];
  final _commentCtrl = TextEditingController();
  bool _isLoading = true;

  /// Biến lưu trữ nội dung văn bản sau khi đã lọc bỏ các mã kỹ thuật (như mã sản phẩm đính kèm).
  String _cleanedContent = "";
  /// Danh sách các đường dẫn hình ảnh đã được giải mã từ chuỗi JSON của server.
  List<String> _decodedImages = [];
  /// Bộ định dạng tiền tệ tĩnh giúp tiết kiệm tài nguyên hệ thống khi hiển thị giá sản phẩm.
  static final NumberFormat _currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    /// Tải dữ liệu chi tiết bản tin ngay khi khởi tạo màn hình.
    _loadDetail();
  }

  /// Chức năng: Giải phóng bộ điều khiển nhập liệu bình luận khi thoát khỏi màn hình.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  /// Chức năng: Gọi API lấy chi tiết bản tin, xử lý bóc tách nội dung văn bản và hình ảnh.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void> xử lý bất đồng bộ.
  Future<void> _loadDetail() async {
    try {
      final res = await context.read<BaseProvider>().apiService.getNewsDetail(widget.newsId);
      if (mounted) {
        final data = res['data'] as Map<String, dynamic>;

        /// Thực hiện lọc bỏ thẻ nhúng sản phẩm [[products:...]] khỏi nội dung hiển thị chính.
        final rawContent = data['content'] ?? "";
        _cleanedContent = rawContent.replaceAll(RegExp(r'\[\[products:.*?\]\]'), "").trim();

        /// Giải mã chuỗi JSON danh sách hình ảnh được gửi từ Backend Laravel.
        final String? imgJson = data['images'];
        if (imgJson != null && imgJson.isNotEmpty) {
          _decodedImages = List<String>.from(jsonDecode(imgJson));
        }

        setState(() {
          _news = data;
          /// Chuyển đổi danh sách sản phẩm liên quan từ JSON sang đối tượng PhoneModel.
          _linkedProducts = (res['linked_products'] as List)
              .map((e) => PhoneModel.fromJson(e))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("❌ Lỗi tải chi tiết tin: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    /// Hiển thị vòng xoay nếu dữ liệu đang trong quá trình nạp.
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    /// Hiển thị thông báo nếu không nạp được dữ liệu bản tin.
    if (_news == null) return const Scaffold(body: Center(child: Text("Không tìm thấy tin tức")));

    /// Lắng nghe chọn lọc các thay đổi về giao diện và người dùng để tối ưu render.
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);
    final px = context.select<BaseProvider, double>((p) => p.textOffset);
    final user = context.select<BaseProvider, dynamic>((p) => p.user);
    final token = context.read<BaseProvider>().token;

    /// Kiểm tra quyền hạn: Người xem có phải chủ bài viết hoặc quản trị viên không.
    final isOwner = _news!['shop_id'] == user?.shop?.id;
    final isAdmin = user?.role == 'admin';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: CustomScrollView(
        /// Sử dụng hiệu ứng vật lý cuộn của iOS/Android mượt mà.
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                /// Hiển thị tiêu đề bài viết.
                Text(_news!['title'],
                    style: TextStyle(fontSize: 22 + px, fontWeight: FontWeight.bold, height: 1.3)),
                /// Hiển thị thông tin Shop đăng bài.
                _buildShopHeader(px, isDark),
                const Divider(height: 32),

                /// Hiển thị nội dung văn bản đã được làm sạch thẻ nhúng.
                Text(_cleanedContent,
                    style: TextStyle(fontSize: 15 + px, height: 1.7, color: isDark ? Colors.white70 : Colors.black87)),

                const SizedBox(height: 24),

                /// Nếu bài viết có gắn kèm sản phẩm, hiển thị danh sách sản phẩm liên quan.
                if (_linkedProducts.isNotEmpty) ...[
                  Text("SẢN PHẨM TRONG BÀI",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 13 + px)),
                  const SizedBox(height: 12),
                  _buildLinkedProductsList(px, isDark),
                ],

                const SizedBox(height: 32),
                /// Khu vực bình luận của bài viết.
                _buildCommentSection(px, isDark),
                const SizedBox(height: 50),
              ]),
            ),
          ),
        ],
      ),
      /// Thanh hành động dưới cùng (Like, Comment, Sửa/Xóa).
      bottomNavigationBar: _buildBottomAction(user, isOwner, isAdmin, token, px, isDark),
    );
  }

  /// Chức năng: Xây dựng thanh tiêu đề dạng trượt (Sliver) kèm hình ảnh bản tin.
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      stretch: true,
      flexibleSpace: FlexibleSpaceBar(
        /// Hiển thị hình ảnh đầu tiên của bài viết làm nền cho AppBar.
        background: _decodedImages.isNotEmpty
            ? ImageHelper.load(_decodedImages[0], fit: BoxFit.cover)
            : Container(color: Colors.blueGrey),
      ),
    );
  }

  /// Chức năng: Hiển thị thông tin tên Shop và nút theo dõi.
  Widget _buildShopHeader(double px, bool isDark) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.store, color: Colors.white)),
      title: Text(_news!['shop']['name'],
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px)),
      subtitle: Text("Đối tác tin cậy của TSP", style: TextStyle(fontSize: 11 + px)),
      trailing: OutlinedButton(
          style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          onPressed: () {},
          child: Text("Theo dõi", style: TextStyle(fontSize: 12 + px))
      ),
    );
  }

  /// Chức năng: Hiển thị danh sách ngang các sản phẩm điện thoại được nhắc đến trong bài.
  Widget _buildLinkedProductsList(double px, bool isDark) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        cacheExtent: 500,
        itemCount: _linkedProducts.length,
        itemBuilder: (ctx, i) {
          final p = _linkedProducts[i];
          return GestureDetector(
            /// Khi nhấn vào sản phẩm sẽ chuyển hướng sang màn hình chi tiết máy.
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhoneDetailScreen(slug: p.slug))),
            child: Container(
              width: 260,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(16)
              ),
              child: Row(
                children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ImageHelper.load(p.thumbnailUrl, width: 60, height: 60, fit: BoxFit.cover)
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 + px)),
                        Text(_currency.format(p.price),
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12 + px)),
                      ]
                  ))
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Chức năng: Xây dựng thanh công cụ dưới cùng dựa trên vai trò của người dùng.
  Widget _buildBottomAction(user, bool isOwner, bool isAdmin, token, double px, bool isDark) {
    return Container(
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              /// Nút yêu thích (Like) bài viết.
              IconButton(
                  icon: const Icon(Icons.favorite_border, color: Colors.red),
                  onPressed: () => context.read<BaseProvider>().apiService.likeNews(widget.newsId, token)
              ),
              const SizedBox(width: 12),
              Expanded(
                /// Logic phân quyền hiển thị nút: Chủ bài (Sửa), Admin (Xóa), Người dùng (Bình luận).
                child: isOwner
                    ? ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () {},
                    child: Text("SỬA BÀI VIẾT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px)))
                    : (isAdmin
                    ? ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () => _deleteNews(token),
                    child: Text("XÓA BÀI VI PHẠM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13 + px)))
                    : ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0047AB), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () => _showCommentInput(isDark, px),
                    child: Text("VIẾT BÌNH LUẬN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14 + px)))
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Chức năng: Hiển thị bảng nhập liệu bình luận từ dưới lên (BottomSheet).
  void _showCommentInput(bool isDark, double px) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Row(
          children: [
            Expanded(child: TextField(
                controller: _commentCtrl,
                autofocus: true,
                style: TextStyle(fontSize: 14 + px),
                decoration: const InputDecoration(hintText: "Nhập bình luận...", border: InputBorder.none)
            )),
            IconButton(icon: const Icon(Icons.send, color: Colors.blue), onPressed: _submitComment),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Xử lý logic gửi nội dung bình luận lên máy chủ.
  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;

    final token = context.read<BaseProvider>().token!;
    final res = await context.read<BaseProvider>().apiService.sendComment(widget.newsId, text, token);
    if (res.data['success'] && mounted) {
      _commentCtrl.clear();
      Navigator.pop(context);
      _loadDetail();
      Fluttertoast.showToast(msg: "Đã gửi!");
    }
  }

  /// Chức năng: Thực hiện lệnh xóa bản tin (dành cho Admin).
  void _deleteNews(token) async {
    final res = await context.read<BaseProvider>().apiService.deleteNews(widget.newsId, token);
    if (res.data['success'] && mounted) {
      Navigator.pop(context);
      Fluttertoast.showToast(msg: "Đã xóa!");
    }
  }

  /// Chức năng: Xây dựng khu vực hiển thị danh sách các phản hồi của người dùng.
  Widget _buildCommentSection(double px, bool isDark) {
    final List comments = _news!['comments'] ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("BÌNH LUẬN (${comments.length})",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15 + px)),
        const SizedBox(height: 16),

        /// Duyệt danh sách bình luận và hiển thị từng dòng thông tin người dùng.
        ...comments.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CircleAvatar(radius: 15, child: Icon(Icons.person, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c['user']['name'], style: TextStyle(fontSize: 13 + px, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(c['content'], style: TextStyle(fontSize: 13 + px, color: isDark ? Colors.white70 : Colors.black87)),
                ],
              ))
            ],
          ),
        )),
      ],
    );
  }
}