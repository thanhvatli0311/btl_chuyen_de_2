import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../data/models/phone_model.dart';
import '../../../data/models/review_model.dart';
import '../../../data/repositories/api_service.dart';
import '../../../core/utils/image_helper.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/base_provider.dart';

import '../chat/chat_detail_screen.dart';
import 'cart_screen.dart';

class PhoneDetailScreen extends StatefulWidget {
  final String slug;
  const PhoneDetailScreen({super.key, required this.slug});

  @override
  State<PhoneDetailScreen> createState() => _PhoneDetailScreenState();
}

class _PhoneDetailScreenState extends State<PhoneDetailScreen> {
  /// Khởi tạo dịch vụ API để giao tiếp với Backend Laravel.
  final ApiService _apiService = ApiService();

  /// Biến lưu trữ dữ liệu chi tiết điện thoại sau khi nạp từ server.
  PhoneModel? _phone;

  /// Trạng thái theo dõi quá trình tải dữ liệu ban đầu.
  bool _isLoading = true;

  /// Bộ định dạng tiền tệ tĩnh để tối ưu tài nguyên CPU, tránh khởi tạo lại liên tục.
  static final NumberFormat _currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    /// Tự động nạp dữ liệu chi tiết sản phẩm ngay khi màn hình khởi tạo.
    _loadDetail();
  }

  /// Chức năng: Gọi API lấy thông tin chi tiết điện thoại dựa trên Slug.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có (Cập nhật dữ liệu vào biến trạng thái _phone).
  void _loadDetail() async {
    try {
      final data = await _apiService.getPhoneDetail(widget.slug);
      if (mounted) {
        setState(() {
          _phone = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi tải dữ liệu!");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    /// Lắng nghe chọn lọc các thay đổi về giao diện và cấu hình cỡ chữ toàn cục.
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);
    final px = context.select<BaseProvider, double>((p) => p.textOffset);
    final base = context.read<BaseProvider>();

    /// Hiển thị màn hình chờ hoặc thông báo lỗi nếu không có dữ liệu.
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_phone == null) return const Scaffold(body: Center(child: Text("Không tìm thấy máy")));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: _buildAppBar(context, isDark),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Hiển thị trình chiếu hình ảnh sản phẩm.
            _buildImageSlider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  /// Hiển thị tên máy và các mức giá.
                  _buildPriceSection(_phone!, px),
                  const SizedBox(height: 12),
                  /// Hiển thị nhãn tình trạng và tồn kho.
                  _buildStatusBadges(_phone!),
                  const SizedBox(height: 24),
                  /// Hiển thị thông tin thương hiệu.
                  _buildBrandRow(_phone!, px),

                  const SizedBox(height: 24),
                  _buildSectionTitle("THÔNG SỐ KỸ THUẬT", px),
                  const Divider(),
                  /// Duyệt qua danh sách thông số và hiển thị theo hàng.
                  ..._phone!.specs.map((s) => _buildSpecRow(s.key, s.value, px)),

                  const SizedBox(height: 24),
                  _buildSectionTitle("MÔ TẢ SẢN PHẨM", px),
                  const Divider(),
                  /// Hiển thị nội dung mô tả chi tiết từ người bán.
                  Text(
                    _phone!.description,
                    style: TextStyle(height: 1.6, color: isDark ? Colors.white70 : Colors.black87, fontSize: 14 + px),
                  ),
                  const SizedBox(height: 32),
                  /// Khu vực hiển thị và viết đánh giá của người dùng.
                  _buildReviewSection(base, isDark, px),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      /// Thanh công cụ phía dưới cùng để Chat và Thêm vào giỏ hàng.
      bottomNavigationBar: _buildBottomBar(base, isDark, px),
    );
  }

  /// Chức năng: Xây dựng thanh tiêu đề của màn hình.
  /// Tham số đầu vào: [context], [isDark].
  /// Giá trị trả về: PreferredSizeWidget (AppBar).
  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      title: const Text("Chi tiết sản phẩm", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      backgroundColor: Theme.of(context).cardColor,
      elevation: 0,
      centerTitle: true,
      actions: [
        /// Biểu tượng giỏ hàng kèm số lượng sản phẩm được nạp động.
        Consumer<CartProvider>(
          builder: (context, cart, _) => Badge(
            label: Text(cart.items.length.toString()),
            isLabelVisible: cart.items.isNotEmpty,
            child: IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen())),
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  /// Chức năng: Hiển thị bộ sưu tập ảnh sản phẩm có thể vuốt ngang.
  /// Giá trị trả về: Widget khung ảnh Slider.
  Widget _buildImageSlider() {
    return Container(
      height: 320,
      width: double.infinity,
      color: Colors.white,
      child: Stack(
        children: [
          /// Kết hợp Ảnh đại diện (Thumbnail) và danh sách Ảnh phụ.
          PageView.builder(
            itemCount: _phone!.images.length + 1,
            itemBuilder: (context, index) {
              final String url = index == 0 ? _phone!.thumbnailUrl : _phone!.images[index - 1];
              return ImageHelper.load(url, fit: BoxFit.contain);
            },
          ),
          /// Hiển thị biểu ngữ nếu sản phẩm đang được áp dụng khuyến mãi.
          if (_phone!.discountPrice != null)
            Positioned(
              top: 20,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: Colors.red,
                child: const Text("GIẢM GIÁ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }

  /// Chức năng: Hiển thị thông tin giá bán và tên sản phẩm.
  /// Tham số đầu vào: [phone] model, [px] cỡ chữ offset.
  Widget _buildPriceSection(PhoneModel phone, double px) {
    final mainPrice = phone.discountPrice ?? phone.price;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(phone.title, style: TextStyle(fontSize: 22 + px, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Row(
          children: [
            /// Hiển thị giá hiện tại (có thể là giá đã giảm).
            Text(
              _currency.format(mainPrice),
              style: const TextStyle(fontSize: 26, color: Colors.blueAccent, fontWeight: FontWeight.w900),
            ),
            /// Hiển thị giá gốc bị gạch ngang nếu sản phẩm đang giảm giá.
            if (phone.discountPrice != null) ...[
              const SizedBox(width: 12),
              Text(
                _currency.format(phone.price),
                style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough, fontSize: 14),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// Chức năng: Hiển thị các nhãn tình trạng máy và số lượng trong kho.
  Widget _buildStatusBadges(PhoneModel phone) {
    return Wrap(
      spacing: 8,
      children: [
        _statusChip(Icons.verified_user_outlined, "Mới ${phone.condition}"),
        _statusChip(Icons.inventory_2_outlined, "Kho: ${phone.stock}"),
      ],
    );
  }

  /// Chức năng: Hiển thị thông tin hãng sản xuất.
  Widget _buildBrandRow(PhoneModel phone, double px) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text("Hãng sản xuất: ", style: TextStyle(color: Colors.grey, fontSize: 14 + px)),
          Text(phone.brand?.name ?? "Đang cập nhật",
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent, fontSize: 14 + px)),
        ],
      ),
    );
  }

  /// Chức năng: Xây dựng nhãn trạng thái (Chip) nhỏ kèm biểu tượng.
  Widget _statusChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.blueAccent),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        ],
      ),
    );
  }

  /// Chức năng: Tạo tiêu đề cho các phân đoạn trong trang chi tiết.
  Widget _buildSectionTitle(String title, double px) {
    return Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16 + px, letterSpacing: 1));
  }

  /// Chức năng: Hiển thị một hàng thông số kỹ thuật (Ví dụ: RAM: 8GB).
  Widget _buildSpecRow(String key, String value, double px) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          /// Cột tên thông số có độ rộng cố định.
          SizedBox(width: 120, child: Text(key, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          /// Cột giá trị thông số tự giãn nở.
          Expanded(child: Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 + px))),
        ],
      ),
    );
  }

  /// Chức năng: Xây dựng khu vực quản lý và hiển thị các đánh giá từ người mua.
  /// Tham số đầu vào: [base] provider, [isDark], [px].
  Widget _buildReviewSection(BaseProvider base, bool isDark, double px) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle("ĐÁNH GIÁ (${_phone!.reviews.length})", px),
            /// Nút nhấn để mở bảng viết đánh giá mới.
            TextButton.icon(
              onPressed: () => _showWriteReviewModal(base.token, isDark),
              icon: const Icon(Icons.edit_note, size: 20),
              label: const Text("Viết đánh giá"),
            ),
          ],
        ),
        const Divider(),
        /// Thông báo nếu sản phẩm chưa có lượt đánh giá nào.
        if (_phone!.reviews.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text("Chưa có đánh giá nào.", style: TextStyle(color: Colors.grey))),
          )
        else
        /// Hiển thị danh sách các thẻ đánh giá.
          Column(
            children: _phone!.reviews.map((m) => _buildReviewCard(m, isDark, px)).toList(),
          ),
      ],
    );
  }

  /// Chức năng: Xây dựng thẻ hiển thị thông tin một lượt đánh giá cá nhân.
  /// Tham số đầu vào: [review] model, [isDark], [px].
  Widget _buildReviewCard(ReviewModel review, bool isDark, double px) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              /// Ảnh đại diện của người đánh giá.
              CircleAvatar(
                radius: 16,
                backgroundImage: review.userAvatar != null
                    ? NetworkImage(ImageHelper.buildImageUrl(review.userAvatar)) : null,
                child: review.userAvatar == null ? const Icon(Icons.person, size: 20) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const Text("Đã mua hàng", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              /// Nút sửa chỉ hiện nếu đây là đánh giá của chính người dùng hiện tại.
              if (review.userId == context.read<BaseProvider>().user?.id)
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                  onPressed: () => _showWriteReviewModal(context.read<BaseProvider>().token, isDark),
                ),
              /// Hiển thị số sao đánh giá.
              Row(
                children: List.generate(5, (i) => Icon(Icons.star, size: 12, color: i < review.rating ? Colors.orange : Colors.grey[300])),
              ),
            ],
          ),
          /// Nội dung bình luận chi tiết (nếu có).
          if (review.comment?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(review.comment!, style: TextStyle(fontSize: 13 + px, color: isDark ? Colors.white70 : Colors.black87, height: 1.4)),
          ],
        ],
      ),
    );
  }

  /// Chức năng: Xây dựng thanh công cụ cố định phía dưới màn hình để thực hiện hành động mua.
  /// Tham số đầu vào: [base] provider, [isDark], [px].
  Widget _buildBottomBar(BaseProvider base, bool isDark, double px) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            /// Nút liên hệ trực tiếp với người bán.
            _actionIconButton(Icons.chat_bubble_outline, "Chat", isDark, () => _handleChat(base)),
            const SizedBox(width: 12),
            /// Nút chính để thêm sản phẩm vào giỏ hàng.
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                onPressed: () => _handleAddToCart(base),
                child: Text("THÊM VÀO GIỎ",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15 + px)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Tạo nút biểu tượng kèm nhãn văn bản cho BottomBar.
  Widget _actionIconButton(IconData icon, String label, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isDark ? Colors.white70 : Colors.blueAccent),
            Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.blueAccent)),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Điều hướng người dùng sang màn hình hội thoại với Shop.
  /// Tham số đầu vào: [base] provider chứa thông tin Token và User.
  void _handleChat(BaseProvider base) {
    /// Ràng buộc: Người dùng phải đăng nhập mới được dùng tính năng Chat.
    if (base.token == null) {
      Fluttertoast.showToast(msg: "Vui lòng đăng nhập!"); return;
    }
    /// Ràng buộc: Không cho phép tự chat với chính gian hàng của mình.
    if (base.user?.id == _phone!.shop?.userId) {
      Fluttertoast.showToast(msg: "Sản phẩm của chính bạn!"); return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(
      receiverId: _phone!.shop!.userId!,
      otherUserName: _phone!.shop!.name,
    )));
  }

  /// Chức năng: Gửi yêu cầu lưu sản phẩm vào giỏ hàng của người dùng.
  /// Tham số đầu vào: [base] provider để lấy Token xác thực.
  void _handleAddToCart(BaseProvider base) async {
    if (base.token == null) {
      Fluttertoast.showToast(msg: "Vui lòng đăng nhập!"); return;
    }
    /// Gọi hàm xử lý thêm vào giỏ trong CartProvider.
    final error = await context.read<CartProvider>().addToCart(_phone!, base.token!);
    Fluttertoast.showToast(msg: error ?? "Đã thêm vào giỏ hàng!");
  }

  /// Chức năng: Hiển thị hộp thoại (BottomSheet) để người dùng nhập nội dung và số sao đánh giá.
  /// Tham số đầu vào: [token] xác thực, [isDark].
  void _showWriteReviewModal(String? token, bool isDark) {
    if (token == null) {
      Fluttertoast.showToast(msg: "Vui lòng đăng nhập để đánh giá!"); return;
    }

    int selectedRating = 5;
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 20, right: 20, top: 20),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(25))),
        child: StatefulBuilder(
          builder: (ctx, setModalState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text("ĐÁNH GIÁ SẢN PHẨM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 10),
              /// Hàng chọn số sao từ 1 đến 5.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) => IconButton(
                  icon: Icon(index < selectedRating ? Icons.star : Icons.star_border, color: Colors.orange, size: 36),
                  onPressed: () => setModalState(() => selectedRating = index + 1),
                )),
              ),
              /// Ô nhập văn bản bình luận.
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Máy dùng tốt không ông? Chia sẻ nhé...",
                  filled: true,
                  fillColor: isDark ? Colors.white10 : Colors.grey[100],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),
              /// Nút gửi dữ liệu lên máy chủ.
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 54),
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  final res = await _apiService.submitReview(
                    token: token,
                    phoneId: _phone!.id,
                    rating: selectedRating,
                    comment: commentController.text.trim(),
                  );

                  if (res.data?['success'] == true) {
                    Fluttertoast.showToast(msg: "Cảm ơn ông đã ủng hộ!");
                    if (ctx.mounted) Navigator.pop(ctx);
                    /// Làm mới dữ liệu trang để hiển thị đánh giá vừa đăng.
                    _loadDetail();
                  } else {
                    Fluttertoast.showToast(msg: res.data?['message'] ?? "Lỗi!");
                  }
                },
                child: const Text("GỬI ĐÁNH GIÁ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}