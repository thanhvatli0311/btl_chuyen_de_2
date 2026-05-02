import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../data/models/phone_model.dart';
import '../../../providers/base_provider.dart';
import '../../../core/utils/image_helper.dart';

class CreateNewsScreen extends StatefulWidget {
  const CreateNewsScreen({super.key});
  @override
  State<CreateNewsScreen> createState() => _CreateNewsScreenState();
}

class _CreateNewsScreenState extends State<CreateNewsScreen> {
  /// Bộ điều khiển nhập liệu cho tiêu đề và nội dung bản tin.
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  /// Công cụ hỗ trợ chọn hình ảnh từ thư viện thiết bị.
  final ImagePicker _picker = ImagePicker();

  /// Danh sách lưu trữ các tệp ảnh đã chọn, danh sách sản phẩm của shop và các ID sản phẩm được đính kèm vào bài viết.
  List<XFile> _newsImages = [];
  List<PhoneModel> _myPhones = [];
  final List<int> _selectedPhoneIds = [];

  /// Trạng thái theo dõi quá trình gửi dữ liệu lên máy chủ.
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    /// Tự động nạp danh sách sản phẩm ngay sau khi giao diện được dựng xong để người dùng có thể chọn đính kèm.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPhones());
  }

  /// Chức năng: Giải phóng bộ nhớ của các Controller khi thoát màn hình.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  @override
  void dispose() {
    /// Hủy các bộ điều khiển văn bản để ngăn chặn rò rỉ bộ nhớ (Memory Leak).
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  /// Chức năng: Gọi API lấy danh sách điện thoại đang kinh doanh của chính chủ Shop.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void> xử lý bất đồng bộ.
  Future<void> _loadPhones() async {
    try {
      final base = context.read<BaseProvider>();
      if (base.token == null) return;

      /// Thực hiện yêu cầu lấy danh sách máy từ server thông qua ApiService.
      final phones = await base.apiService.getMyShopPhones(base.token!);
      if (mounted) setState(() => _myPhones = phones);
    } catch (e) {
      debugPrint("❌ Lỗi lấy danh sách máy: $e");
    }
  }

  /// Chức năng: Mở trình chọn nhiều ảnh từ thư viện và lưu vào danh sách hiển thị tạm thời.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void>.
  Future<void> _pickNewsImages() async {
    /// Sử dụng imageQuality để nén dung lượng ảnh, giúp tăng tốc độ tải lên và tiết kiệm băng thông.
    final List<XFile> images = await _picker.pickMultiImage(imageQuality: 30);
    if (images.isNotEmpty && mounted) {
      setState(() => _newsImages.addAll(images));
    }
  }

  /// Chức năng: Đóng gói dữ liệu và gửi bài viết mới lên hệ thống Laravel.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void>.
  Future<void> _submitNews() async {
    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();

    /// Kiểm tra tính hợp lệ của dữ liệu trước khi gửi đi.
    if (title.isEmpty || content.isEmpty) {
      Fluttertoast.showToast(msg: "Vui lòng nhập tiêu đề và nội dung!");
      return;
    }

    setState(() => _isLoading = true);

    final base = context.read<BaseProvider>();
    final token = base.token!;

    /// Logic: Nếu có sản phẩm đính kèm, thêm mã thẻ sản phẩm vào cuối nội dung để hệ thống tự render.
    String finalContent = content;
    if (_selectedPhoneIds.isNotEmpty) {
      finalContent += "\n[[products:${_selectedPhoneIds.join(',')}]]";
    }

    try {
      /// Gửi yêu cầu lưu bản tin kèm theo các tệp hình ảnh thực tế.
      final res = await base.apiService.storeNewsWithImages(
        title: title,
        content: finalContent,
        imagePaths: _newsImages.map((e) => e.path).toList(),
        token: token,
      );

      /// Xử lý phản hồi từ phía máy chủ.
      if (res.data['success'] == true) {
        Fluttertoast.showToast(msg: "Đăng bài thành công!");
        if (mounted) Navigator.pop(context);
      } else {
        Fluttertoast.showToast(msg: res.data['message'] ?? "Lỗi từ server!");
      }
    } catch (e) {
      debugPrint("❌ LỖI ĐĂNG TIN: $e");
      Fluttertoast.showToast(msg: "Lỗi: ${e.toString()}", backgroundColor: Colors.red);
    } finally {
      /// Đảm bảo tắt vòng xoay loading kể cả khi thành công hay gặp lỗi.
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    /// Lắng nghe thay đổi chọn lọc từ Provider để cập nhật giao diện (Dark Mode, Cỡ chữ).
    final px = context.select<BaseProvider, double>((p) => p.textOffset);
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("TẠO BẢN TIN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17 + px)),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        /// Sử dụng hiệu ứng vật lý cuộn để tạo trải nghiệm mượt mà đặc thù cho Android.
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildInputSection(px, isDark),
          const SizedBox(height: 24),
          _buildImagePickerSection(px, isDark),
          const SizedBox(height: 24),
          _buildProductPickerSection(px, isDark),
          const SizedBox(height: 40),
          _buildSubmitButton(px),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  /// Chức năng: Xây dựng khu vực các ô nhập văn bản (Tiêu đề, Nội dung).
  Widget _buildInputSection(double px, bool isDark) {
    return Column(children: [
      TextField(
        controller: _titleCtrl,
        textInputAction: TextInputAction.next,
        style: TextStyle(fontSize: 14 + px),
        decoration: InputDecoration(
            labelText: "Tiêu đề bài viết",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
        ),
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
        ),
      ),
    ]);
  }

  /// Chức năng: Xây dựng khu vực lựa chọn và quản lý các ảnh minh họa đã chọn.
  Widget _buildImagePickerSection(double px, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("ẢNH MINH HỌA BÀI VIẾT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 + px)),
      const SizedBox(height: 12),
      SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          cacheExtent: 300,
          itemCount: _newsImages.length + 1,
          itemBuilder: (ctx, i) {
            /// Mục cuối cùng luôn là nút để chọn thêm ảnh mới.
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
            /// Hiển thị các ảnh đã được người dùng chọn.
            return Stack(children: [
              Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      image: DecorationImage(image: FileImage(File(_newsImages[i].path)), fit: BoxFit.cover)
                  )
              ),
              /// Nút xóa ảnh đã chọn ra khỏi danh sách tạm thời.
              Positioned(
                  right: 15,
                  top: 5,
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

  /// Chức năng: Xây dựng khu vực cho phép người dùng chọn sản phẩm đính kèm từ danh sách máy của Shop.
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
              /// Logic: Nếu sản phẩm đã được chọn thì gỡ bỏ, nếu chưa thì thêm vào danh sách ID.
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

  /// Chức năng: Xây dựng nút xác nhận gửi bài viết bài với trạng thái tải dữ liệu.
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
          : Text("XÁC NHẬN ĐĂNG TIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15 + px)),
    );
  }
}