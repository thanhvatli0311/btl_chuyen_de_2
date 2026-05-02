import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../providers/news_provider.dart';
import '../../../providers/base_provider.dart';
import '../../../data/models/news_model.dart';
import '../../../core/utils/image_helper.dart';
import '../buyer/phone_detail_screen.dart';

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  State<NewsFeedScreen> createState() => _NewsFeedScreenState();
}

class _NewsFeedScreenState extends State<NewsFeedScreen> {
  /// Bộ định dạng ngày tháng năm tĩnh giúp tối ưu hiệu năng render.
  static final DateFormat _dateFormat = DateFormat('dd MMMM, yyyy');
  /// Bộ định dạng giờ tĩnh dùng cho phần bình luận.
  static final DateFormat _timeFormatter = DateFormat('HH:mm');
  /// Bộ định dạng tiền tệ tĩnh cho giá sản phẩm liên quan.
  static final NumberFormat _currencyFormatter = NumberFormat.decimalPattern();
  /// Biểu thức chính quy dùng để lọc bỏ các thẻ sản phẩm khỏi nội dung văn bản.
  static final RegExp _productTagRegex = RegExp(r'\[\[products:.*?\]\]');

  @override
  void initState() {
    super.initState();
    /// Tự động nạp danh sách tin tức ngay sau khi khung hình đầu tiên được dựng xong.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<BaseProvider>().token;
      context.read<NewsProvider>().fetchNews(token: token);
    });
  }

  @override
  Widget build(BuildContext context) {
    /// Lắng nghe thay đổi chọn lọc từ NewsProvider để tránh rebuild lãng phí.
    final isLoading = context.select<NewsProvider, bool>((p) => p.isLoading);
    final posts = context.select<NewsProvider, List<NewsPostModel>>((p) => p.posts);

    final base = context.read<BaseProvider>();
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);
    final px = context.select<BaseProvider, double>((p) => p.textOffset);
    final token = context.select<BaseProvider, String?>((p) => p.token);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("TIN TỨC",
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 18 + px)),
        centerTitle: true,
        elevation: 0.5,
      ),
      body: isLoading && posts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        /// Chức năng: Kéo xuống để cập nhật lại bảng tin mới nhất.
        onRefresh: () => context.read<NewsProvider>().fetchNews(token: token),
        child: ListView.builder(
          /// Cấu hình vùng đệm để ListView dựng sẵn các thẻ tin tức, giúp cuộn mượt hơn.
          cacheExtent: 500,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) => _buildNewsCard(posts[index], token, isDark, px),
        ),
      ),
    );
  }

  /// Chức năng: Xây dựng giao diện thẻ hiển thị nội dung một bài viết tin tức.
  /// Tham số đầu vào: [post] model dữ liệu, [token] xác thực, [isDark] chế độ tối, [px] cỡ chữ.
  /// Giá trị trả về: Widget dạng Container chứa thông tin bài viết.
  Widget _buildNewsCard(NewsPostModel post, String? token, bool isDark, double px) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5)
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Hiển thị hình ảnh minh họa bài viết nếu có.
          if (post.imageUrl != null)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              child: ImageHelper.load(post.imageUrl!, height: 240, width: double.infinity, fit: BoxFit.cover),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                /// Phần hiển thị thông tin Shop đăng bài.
                _buildShopHeader(post, px),
                const SizedBox(height: 16),
                Text(post.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18 + px, height: 1.2)),
                const SizedBox(height: 8),
                Text(
                  /// Lọc bỏ mã tag sản phẩm khỏi nội dung text thuần túy.
                  post.content.replaceAll(_productTagRegex, ""),
                  style: TextStyle(height: 1.5, color: isDark ? Colors.white70 : Colors.black87, fontSize: 13 + px),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),

                /// Nếu bài viết có gắn kèm sản phẩm, hiển thị danh sách sản phẩm liên quan.
                if (post.linkedProducts.isNotEmpty) _buildLinkedProducts(post, isDark, px),

                const SizedBox(height: 16),
                const Divider(),

                /// Hàng nút tương tác: Thả tim và Bình luận.
                Row(
                  children: [
                    _buildActionButton(
                      icon: post.isLiked ? Icons.favorite : Icons.favorite_border,
                      label: "${post.likesCount}",
                      color: post.isLiked ? Colors.red : Colors.grey,
                      onTap: () {
                        if (token == null) {
                          Fluttertoast.showToast(msg: "Đăng nhập để thả tim nè!");
                        } else {
                          context.read<NewsProvider>().toggleLike(token, post.id);
                        }
                      },
                    ),
                    const SizedBox(width: 24),
                    _buildActionButton(
                      icon: Icons.chat_bubble_outline,
                      label: "${post.commentsCount}",
                      color: Colors.blue,
                      onTap: () => _showCommentModal(post, token),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Chức năng: Xây dựng phần đầu của thẻ tin tức chứa tên shop và ngày đăng.
  /// Tham số đầu vào: [post] model, [px] cỡ chữ.
  Widget _buildShopHeader(NewsPostModel post, double px) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Colors.blue.withOpacity(0.1),
          child: const Icon(Icons.storefront, color: Colors.blue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(post.shop?.name ?? "Cửa hàng TSP",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px)),
              Text(_dateFormat.format(post.createdAt),
                  style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }

  /// Chức năng: Xây dựng danh sách trượt ngang các sản phẩm được gắn thẻ trong bài viết.
  /// Tham số đầu vào: [post] model, [isDark], [px].
  Widget _buildLinkedProducts(NewsPostModel post, bool isDark, double px) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.blue[700]),
            const SizedBox(width: 6),
            Text("SẢN PHẨM TRONG BÀI",
                style: TextStyle(fontSize: 11 + px, fontWeight: FontWeight.bold, color: Colors.blue[700])),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 85,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            cacheExtent: 300,
            itemCount: post.linkedProducts.length,
            itemBuilder: (ctx, i) {
              final p = post.linkedProducts[i];
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PhoneDetailScreen(slug: p.slug))),
                child: Container(
                  width: 200,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.blue.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ImageHelper.load(p.thumbnailUrl, width: 50, height: 50, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12 + px)),
                            Text("${_currencyFormatter.format(p.discountPrice ?? p.price)}đ",
                                style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Chức năng: Hiển thị hộp thoại (BottomSheet) chứa danh sách bình luận của bài viết.
  /// Tham số đầu vào: [post] model bài viết, [token] xác thực.
  void _showCommentModal(NewsPostModel post, String? token) {
    final TextEditingController commentCtrl = TextEditingController();
    int? parentId;
    String? replyToName;
    final Set<int> expandedComments = {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          /// Lọc danh sách bình luận gốc (không phải là câu trả lời).
          final rootComments = post.comments.where((c) => c.parentId == null).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text("BÌNH LUẬN", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Divider(height: 1),

                Expanded(
                  child: rootComments.isEmpty
                      ? const Center(child: Text("Chưa có bình luận nào."))
                      : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rootComments.length,
                    itemBuilder: (context, i) {
                      final parent = rootComments[i];
                      /// Lọc các câu trả lời thuộc về bình luận gốc này.
                      final replies = post.comments.where((c) => c.parentId == parent.id).toList();
                      final bool isExpanded = expandedComments.contains(parent.id);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          /// Hiển thị nội dung bình luận cha.
                          _buildCommentItem(parent, false, () {
                            setModalState(() { parentId = parent.id; replyToName = parent.user?.name; });
                          }),

                          /// Nút điều khiển ẩn/hiện danh sách câu trả lời.
                          if (replies.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 45, bottom: 8),
                              child: InkWell(
                                onTap: () => setModalState(() {
                                  isExpanded ? expandedComments.remove(parent.id) : expandedComments.add(parent.id);
                                }),
                                child: Row(
                                  children: [
                                    Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 18, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Text(isExpanded ? "Thu nhỏ" : "Xem ${replies.length} câu trả lời",
                                        style: const TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),

                          /// Hiển thị danh sách các câu trả lời nếu đang ở trạng thái mở rộng.
                          if (isExpanded)
                            ...replies.map((reply) => Padding(
                              padding: const EdgeInsets.only(left: 40),
                              child: _buildCommentItem(reply, true, () {
                                setModalState(() { parentId = parent.id; replyToName = reply.user?.name; });
                              }),
                            )).toList(),
                        ],
                      );
                    },
                  ),
                ),
                /// Khu vực nhập nội dung bình luận mới.
                _buildInputArea(commentCtrl, parentId, replyToName, token, post, setModalState),
              ],
            ),
          );
        },
      ),
    ).then((_) => commentCtrl.dispose());
  }

  /// Chức năng: Xây dựng giao diện cho từng dòng bình luận đơn lẻ.
  /// Tham số đầu vào: [c] model bình luận, [isReply] xác định là câu trả lời, [onReply] hàm xử lý trả lời.
  /// Giá trị trả về: Widget hàng bình luận.
  Widget _buildCommentItem(NewsCommentModel c, bool isReply, VoidCallback onReply) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: isReply ? 12 : 16, child: const Icon(Icons.person, size: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(c.user?.name ?? "Người dùng", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const Spacer(),
                    Text(_timeFormatter.format(c.createdAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                Text(c.content, style: const TextStyle(fontSize: 13)),
                InkWell(
                  onTap: onReply,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text("Trả lời", style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Chức năng: Xây dựng khu vực nhập văn bản để gửi bình luận hoặc câu trả lời.
  /// Tham số đầu vào: [ctrl] controller, [pId] ID cha, [name] tên người được trả lời, [token], [post], [setModalState].
  Widget _buildInputArea(TextEditingController ctrl, int? pId, String? name, String? token, NewsPostModel post, StateSetter setModalState) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16, left: 16, right: 16, top: 12),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))]
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          /// Hiển thị thông tin nếu đang thực hiện trả lời một bình luận khác.
          if (pId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Text("Đang trả lời $name", style: const TextStyle(fontSize: 11, color: Colors.blue)),
                  const SizedBox(width: 8),
                  GestureDetector(onTap: () => setModalState(() => pId = null), child: const Icon(Icons.cancel, size: 14, color: Colors.red)),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  decoration: InputDecoration(
                    hintText: pId == null ? "Viết bình luận..." : "Viết câu trả lời...",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.1),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.blue),
                onPressed: () async {
                  /// Ràng buộc đăng nhập trước khi được phép bình luận.
                  if (token == null) { Fluttertoast.showToast(msg: "Vui lòng đăng nhập!"); return; }
                  final text = ctrl.text.trim();
                  if (text.isNotEmpty) {
                    /// Thực hiện gửi dữ liệu bình luận lên server thông qua NewsProvider.
                    final ok = await context.read<NewsProvider>().sendComment(token, post.id, text, parentId: pId);
                    if (ok && mounted) {
                      ctrl.clear();
                      Navigator.pop(context);
                      Fluttertoast.showToast(msg: "Đã gửi!");
                    }
                  }
                },
              )
            ],
          ),
        ],
      ),
    );
  }

  /// Chức năng: Tạo ra các nút hành động (Like, Comment) với giao diện đồng nhất.
  /// Tham số đầu vào: [icon] biểu tượng, [label] nhãn văn bản, [color] màu sắc, [onTap] hàm xử lý.
  /// Giá trị trả về: Widget nút bấm tương tác.
  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}