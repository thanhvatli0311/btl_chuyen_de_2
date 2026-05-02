import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../data/models/news_model.dart';
import '../../../data/models/phone_model.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/news_provider.dart';
import '../../../core/utils/image_helper.dart';

class EditNewsScreen extends StatefulWidget {
  final NewsPostModel news;
  const EditNewsScreen({super.key, required this.news});

  @override
  State<EditNewsScreen> createState() => _EditNewsScreenState();
}

class _EditNewsScreenState extends State<EditNewsScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  final ImagePicker _picker = ImagePicker();

  List<XFile> _newsImages = [];
  List<PhoneModel> _myPhones = [];
  List<int> _selectedPhoneIds = [];
  bool _isLoading = false;

  /// Chức năng: Khởi tạo dữ liệu màn hình, bóc tách danh sách ID sản phẩm từ nội dung bài viết.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  @override
  void initState() {
    super.initState();

    /// Khởi tạo tiêu đề bài viết từ dữ liệu truyền vào.
    _titleCtrl = TextEditingController(text: widget.news.title);

    final content = widget.news.content;

    /// Sử dụng biểu thức chính quy (Regex) để tìm kiếm mã đính kèm sản phẩm dạng [[products:id1,id2]].
    final regExp = RegExp(r'\[\[products:(.*?)\]\]');
    final match = regExp.firstMatch(content);

    /// Nếu tìm thấy mã sản phẩm trong nội dung bài viết.
    if (match != null) {
      final idsStr = match.group(1);
      if (idsStr != null && idsStr.isNotEmpty) {
        /// Chuyển đổi chuỗi ID sang danh sách số nguyên để hiển thị trạng thái đã chọn.
        _selectedPhoneIds = idsStr.split(',').map((e) => int.parse(e)).toList();
      }
      /// Lọc bỏ mã sản phẩm ra khỏi nội dung hiển thị trong ô nhập liệu để người dùng dễ sửa văn bản.
      _contentCtrl = TextEditingController(text: content.replaceAll(regExp, "").trim());
    } else {
      _contentCtrl = TextEditingController(text: content);
    }

    /// Đăng ký hàm nạp danh sách máy của Shop sau khi khung hình đầu tiên được dựng xong.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPhones());
  }

  /// Chức năng: Giải phóng tài nguyên hệ thống và bộ nhớ khi màn hình bị đóng.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  @override
  void dispose() {
    /// Hủy các bộ điều khiển văn bản để tránh rò rỉ bộ nhớ (Memory Leak).
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  /// Chức năng: Gọi API lấy danh sách các điện thoại thuộc quyền quản lý của Shop.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void> xử lý bất đồng bộ.
  Future<void> _loadPhones() async {
    try {
      final base = context.read<BaseProvider>();
      if (base.token == null) return;

      final phones = await base.apiService.getMyShopPhones(base.token!);
      if (mounted) setState(() => _myPhones = phones);
    } catch (e) {
      debugPrint("❌ Lỗi lấy danh sách máy: $e");
    }
  }

  /// Chức năng: Mở trình chọn ảnh trên điện thoại để người dùng chọn nhiều ảnh minh họa mới.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void>.
  Future<void> _pickNewsImages() async {
    /// Nén chất lượng ảnh xuống 30% để giảm băng thông và tăng tốc độ tải lên server.
    final List<XFile> images = await _picker.pickMultiImage(imageQuality: 30);
    if (images.isNotEmpty && mounted) {
      setState(() => _newsImages.addAll(images));
    }
  }

  /// Chức năng: Kiểm tra tính hợp lệ của dữ liệu và gửi yêu cầu cập nhật bài viết lên Server.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void>.
  Future<void> _submitNews() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    /// Ràng buộc: Không được để trống tiêu đề hoặc nội dung bài viết.
    if (title.isEmpty || content.isEmpty) {
      Fluttertoast.showToast(msg: "Vui lòng nhập đầy đủ thông tin!");
      return;
    }

    setState(() => _isLoading = true);
    final base = context.read<BaseProvider>();
    final token = base.token!;

    String finalContent = content;

    /// Nếu có sản phẩm được chọn, đính kèm mã sản phẩm vào cuối nội dung theo định dạng quy định.
    if (_selectedPhoneIds.isNotEmpty) {
      finalContent += "\n[[products:${_selectedPhoneIds.join(',')}]]";
    }

    try {
      /// Thực hiện gọi hàm cập nhật thông qua NewsProvider.
      final success = await context.read<NewsProvider>().updateNewsPost(
        id: widget.news.id,
        title: title,
        content: finalContent,
        imagePaths: _newsImages.map((e) => e.path).toList(),
        token: token,
      );

      /// Nếu cập nhật thành công và màn hình vẫn còn tồn tại, thông báo và quay lại trang trước.
      if (success && mounted) {
        Fluttertoast.showToast(msg: "Cập nhật bài thành công!");
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("❌ LỖI CẬP NHẬT: $e");
      Fluttertoast.showToast(msg: "Lỗi: ${e.toString()}");
    } finally {
      /// Đảm bảo tắt trạng thái loading kể cả khi thành công hay thất bại.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    /// Lắng nghe chọn lọc thay đổi về giao diện và cỡ chữ để tối ưu hiệu năng vẽ lại màn hình.
    final px = context.select<BaseProvider, double>((p) => p.textOffset);
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("CHỈNH SỬA BẢN TIN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17 + px)),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          /// Khu vực các ô nhập liệu văn bản.
          _buildInputSection(px, isDark),
          const SizedBox(height: 24),
          /// Khu vực quản lý hình ảnh minh họa.
          _buildImagePickerSection(px, isDark),
          const SizedBox(height: 24),
          /// Khu vực lựa chọn sản phẩm đính kèm từ kho của Shop.
          _buildProductPickerSection(px, isDark),
          const SizedBox(height: 40),
          /// Nút xác nhận lưu thay đổi.
          _buildSubmitButton(px),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  /// Chức năng: Xây dựng các ô nhập tiêu đề và nội dung bài viết.
  Widget _buildInputSection(double px, bool isDark) {
    return Column(children: [
      TextField(
          controller: _titleCtrl,
          textInputAction: TextInputAction.next,
          style: TextStyle(fontSize: 14 + px),
          decoration: InputDecoration(
              labelText: "Tiêu đề bài viết",
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
          )
      ),
      const SizedBox(height: 16),
      TextField(
          controller: _contentCtrl,
          maxLines: 6,
          style: TextStyle(fontSize: 14 + px),
          decoration: InputDecoration(
              labelText: "Nội dung bài viết",
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
          )
      ),
    ]);
  }

  /// Chức năng: Xây dựng khu vực chọn ảnh, cho phép thêm ảnh mới và xóa ảnh vừa chọn.
  Widget _buildImagePickerSection(double px, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("ẢNH MINH HỌA (Chọn mới sẽ thay thế toàn bộ)",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 + px)),
      const SizedBox(height: 12),
      SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          cacheExtent: 300,
          itemCount: _newsImages.length + 1,
          itemBuilder: (ctx, i) {
            /// Mục cuối cùng là nút để mở thư viện chọn ảnh.
            if (i == _newsImages.length) {
              return GestureDetector(
                onTap: _pickNewsImages,
                child: Container(
                    width: 100,
                    decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey[200],
                        borderRadius: BorderRadius.circular(15)
                    ),
                    child: const Icon(Icons.add_a_photo, color: Colors.blue)
                ),
              );
            }
            /// Hiển thị các ảnh đã chọn kèm nút xóa nhanh.
            return Stack(children: [
              Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      image: DecorationImage(image: FileImage(File(_newsImages[i].path)), fit: BoxFit.cover)
                  )
              ),
              Positioned(
                  right: 15, top: 5,
                  child: GestureDetector(
                      onTap: () => setState(() => _newsImages.removeAt(i)),
                      child: const CircleAvatar(
                          radius: 10,
                          backgroundColor: Colors.red,
                          child: Icon(Icons.close, size: 12, color: Colors.white)
                      )
                  )
              ),
            ]);
          },
        ),
      ),
    ]);
  }

  /// Chức năng: Xây dựng khung danh sách sản phẩm để Shop lựa chọn đính kèm vào tin.
  Widget _buildProductPickerSection(double px, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("SẢN PHẨM ĐÍNH KÈM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 + px)),
      const SizedBox(height: 12),
      SizedBox(
        height: 115,
        child: _myPhones.isEmpty
            ? Center(child: Text("Shop chưa có sản phẩm nào", style: TextStyle(color: Colors.grey, fontSize: 12 + px)))
            : ListView.builder(
          scrollDirection: Axis.horizontal,
          cacheExtent: 500,
          itemCount: _myPhones.length,
          itemBuilder: (ctx, i) {
            final p = _myPhones[i];
            final isSelected = _selectedPhoneIds.contains(p.id);
            return GestureDetector(
              /// Khi chạm vào: Nếu đã chọn thì bỏ chọn, nếu chưa thì thêm vào danh sách đính kèm.
              onTap: () => setState(() => isSelected ? _selectedPhoneIds.remove(p.id) : _selectedPhoneIds.add(p.id)),
              child: Container(
                width: 100,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                    border: Border.all(color: isSelected ? Colors.blue : Colors.transparent, width: 2),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]
                ),
                child: Column(children: [
                  Expanded(child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                      child: ImageHelper.load(p.thumbnailUrl, fit: BoxFit.contain)
                  )),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(p.title, maxLines: 1, style: TextStyle(fontSize: 10 + px), overflow: TextOverflow.ellipsis),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  /// Chức năng: Tạo nút bấm gửi dữ liệu kèm trạng thái vòng xoay tải bài viết.
  Widget _buildSubmitButton(double px) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitNews,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0047AB),
        minimumSize: const Size(double.infinity, 55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: _isLoading
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text("LƯU THAY ĐỔI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15 + px)),
    );
  }
}