import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:dio/dio.dart';
import '../../../data/models/phone_model.dart';
import '../../../providers/base_provider.dart';
import '../../../core/utils/image_helper.dart';

class CreateNewsScreen extends StatefulWidget {
  const CreateNewsScreen({super.key});
  @override
  State<CreateNewsScreen> createState() => _CreateNewsScreenState();
}

class _CreateNewsScreenState extends State<CreateNewsScreen> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  List<XFile> _newsImages = [];
  List<PhoneModel> _myPhones = [];
  List<int> _selectedPhoneIds = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPhones();
  }

  Future<void> _loadPhones() async {
    final token = context.read<BaseProvider>().token;
    final phones = await context.read<BaseProvider>().apiService.getMyShopPhones(token!);
    setState(() => _myPhones = phones);
  }

  Future<void> _pickNewsImages() async {
    final List<XFile> images = await _picker.pickMultiImage(imageQuality: 30);
    if (images.isNotEmpty) setState(() => _newsImages.addAll(images));
  }

  Future<void> _submitNews() async {
    if (_titleCtrl.text.isEmpty || _contentCtrl.text.isEmpty) {
      Fluttertoast.showToast(msg: "Vui lòng nhập tiêu đề và nội dung!"); return;
    }

    setState(() => _isLoading = true);
    final token = context.read<BaseProvider>().token!;

    String finalContent = _contentCtrl.text;
    if (_selectedPhoneIds.isNotEmpty) {
      finalContent += "\n[[products:${_selectedPhoneIds.join(',')}]]";
    }

    try {
      final res = await context.read<BaseProvider>().apiService.storeNewsWithImages(
        title: _titleCtrl.text,
        content: finalContent,
        imagePaths: _newsImages.map((e) => e.path).toList(),
        token: token,
      );

      if (res.data != null && res.data['success'] == true) {
        Fluttertoast.showToast(msg: "Đăng bài thành công!", backgroundColor: Colors.green);
        Navigator.pop(context);
      } else {
        String msg = res.data != null ? (res.data['message'] ?? "Lỗi từ server!") : "Lỗi hệ thống";
        Fluttertoast.showToast(msg: msg);
      }
    } catch (e) {
      if (e is DioException) {
        debugPrint("❌ LỖI SERVER: ${e.response?.data}");
        Fluttertoast.showToast(msg: "Lỗi: ${e.response?.data?['message'] ?? 'Máy chủ lỗi'}", backgroundColor: Colors.red);
      } else {
        debugPrint("❌ LỖI KHÁC: $e");
        Fluttertoast.showToast(msg: "Lỗi kết nối mạng!", backgroundColor: Colors.red);
      }
    }
    finally { if (mounted) setState(() => _isLoading = false); }
  }


  @override
  Widget build(BuildContext context) {
    final px = context.read<BaseProvider>().textOffset;
    final isDark = context.read<BaseProvider>().isDarkMode;

    return Scaffold(
      appBar: AppBar(title: const Text("TẠO BẢN TIN"), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildInputSection(px, isDark),
          const SizedBox(height: 20),
          _buildImagePickerSection(px, isDark),
          const SizedBox(height: 20),
          _buildProductPickerSection(px, isDark),
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _isLoading ? null : _submitNews,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0047AB),
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("XÁC NHẬN ĐĂNG TIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildInputSection(double px, bool isDark) {
    return Column(children: [
      TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: "Tiêu đề bài viết", border: OutlineInputBorder())),
      const SizedBox(height: 16),
      TextField(controller: _contentCtrl, maxLines: 6, decoration: const InputDecoration(labelText: "Nội dung bài viết", alignLabelWithHint: true, border: OutlineInputBorder())),
    ]);
  }

  Widget _buildImagePickerSection(double px, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("ẢNH MINH HỌA BÀI VIẾT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 + px)),
      const SizedBox(height: 10),
      SizedBox(
        height: 100,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _newsImages.length + 1,
          itemBuilder: (ctx, i) {
            if (i == _newsImages.length) {
              return GestureDetector(
                onTap: _pickNewsImages,
                child: Container(width: 100, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.add_a_photo, color: Colors.blue)),
              );
            }
            return Stack(children: [
              Container(width: 100, margin: const EdgeInsets.only(right: 10), decoration: BoxDecoration(borderRadius: BorderRadius.circular(15), image: DecorationImage(image: FileImage(File(_newsImages[i].path)), fit: BoxFit.cover))),
              Positioned(right: 15, top: 5, child: GestureDetector(onTap: () => setState(() => _newsImages.removeAt(i)), child: const CircleAvatar(radius: 10, backgroundColor: Colors.red, child: Icon(Icons.close, size: 12, color: Colors.white)))),
            ]);
          },
        ),
      ),
    ]);
  }

  Widget _buildProductPickerSection(double px, bool isDark) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text("SẢN PHẨM ĐÍNH KÈM", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13 + px)),
      const SizedBox(height: 10),
      SizedBox(
        height: 110,
        child: _myPhones.isEmpty
            ? const Center(child: Text("Shop chưa có sản phẩm nào"))
            : ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _myPhones.length,
          itemBuilder: (ctx, i) {
            final p = _myPhones[i];
            final isSelected = _selectedPhoneIds.contains(p.id);
            return GestureDetector(
              onTap: () => setState(() => isSelected ? _selectedPhoneIds.remove(p.id) : _selectedPhoneIds.add(p.id)),
              child: Container(
                width: 90, margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(border: Border.all(color: isSelected ? Colors.blue : Colors.transparent, width: 2), borderRadius: BorderRadius.circular(12)),
                child: Column(children: [
                  Expanded(child: ImageHelper.load(p.thumbnailUrl)),
                  Text(p.title, maxLines: 1, style: const TextStyle(fontSize: 9), overflow: TextOverflow.ellipsis),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}