import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../../data/models/news_model.dart';
import '../../../providers/base_provider.dart';
import '../../../core/network/api_config.dart';
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

  static final DateFormat _dateTimeFormatter = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    try {
      final base = context.read<BaseProvider>();
      final token = base.token;
      if (token == null) return;

      final data = await base.apiService.getNewsManagement(token);

      if (mounted) {
        setState(() {
          _newsList = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint("❌ Lỗi nạp quản lý bản tin: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
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
        onRefresh: _fetchNews,
        child: _newsList.isEmpty
            ? Center(child: Text("Chưa có bài viết nào.",
            style: TextStyle(fontSize: 14 + px, color: Colors.grey)))
            : ListView.builder(
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

  Widget _buildNewsManageCard(dynamic rawItem, bool isAdmin, double px, bool isDark, String token) {
    // Ép kiểu an toàn sang Model để xử lý ảnh JSON/List tự động
    final news = NewsPostModel.fromJson(rawItem as Map<String, dynamic>);

    // Lấy ảnh đầu tiên từ mảng ảnh đã được Model xử lý
    final String? firstImage = news.imageUrl;

    // Tạo đường dẫn ảnh đầy đủ với Domain và Storage của Laravel
    String? fullPath;
    if (firstImage != null) {
      fullPath = firstImage.startsWith('http')
          ? firstImage
          : "${ApiConfig.domainUrl}/storage/$firstImage";
    }

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => NewsDetailScreen(newsId: news.id)
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
                    child: fullPath != null
                        ? ImageHelper.load(fullPath, width: 80, height: 80, fit: BoxFit.cover)
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
                        Text(news.title,
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.storefront, size: 14, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text(news.user?.name ?? news.shop?.name ?? "Người đăng",
                                style: TextStyle(color: Colors.blue, fontSize: 12 + px)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Đăng lúc: ${_dateTimeFormatter.format(news.createdAt)}",
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
                  Row(
                    children: [
                      _buildStatItem(Icons.favorite_border, news.likesCount.toString(), Colors.red),
                      const SizedBox(width: 16),
                      _buildStatItem(Icons.chat_bubble_outline, news.commentsCount.toString(), Colors.orange),
                    ],
                  ),
                  Row(
                    children: [
                      if (!isAdmin)
                        IconButton(
                          icon: const Icon(Icons.edit_note, color: Colors.blue),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => EditNewsScreen(news: news)),
                            ).then((_) => _fetchNews());
                          },
                        ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () => _confirmDelete(news.id, token),
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

  Widget _buildStatItem(IconData icon, String value, Color color) {
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 4),
      Text(value, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
    ]);
  }

  void _confirmDelete(int id, String token) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Xác nhận xóa bài?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Dữ liệu bài viết sẽ bị xóa vĩnh viễn khỏi hệ thống."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, elevation: 0),
            onPressed: () async {
              final api = context.read<BaseProvider>().apiService;
              final res = await api.deleteNews(id, token);

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