import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:dio/dio.dart';
import '../../../providers/base_provider.dart';
import '../../../data/repositories/api_service.dart';
import '../../../data/models/category_brand_model.dart';
import '../../../data/models/phone_model.dart';
import '../../../core/utils/image_helper.dart';

class AddPhoneScreen extends StatefulWidget {
  final PhoneModel? phone;
  const AddPhoneScreen({super.key, this.phone});

  @override
  State<AddPhoneScreen> createState() => _AddPhoneScreenState();
}

class _AddPhoneScreenState extends State<AddPhoneScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  bool _isSubmitting = false;
  bool _isPickingImage = false;

  /// Khai báo các bộ điều khiển nhập liệu cho thông tin sản phẩm và thông số kỹ thuật.
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _stockCtrl = TextEditingController();

  final TextEditingController _ramCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();
  final TextEditingController _screenCtrl = TextEditingController();
  final TextEditingController _storageCtrl = TextEditingController();
  final TextEditingController _cpuCtrl = TextEditingController();

  final TextEditingController _searchBrandCtrl = TextEditingController();
  final TextEditingController _newBrandNameCtrl = TextEditingController();
  bool _isAddingNewBrand = false;

  XFile? _thumbnail;
  final List<XFile> _subImages = [];
  List<BrandModel> _brands = [];
  List<CategoryModel> _categories = [];
  int? _selectedBrandId, _selectedCategoryId;
  String _condition = 'new';

  @override
  void initState() {
    super.initState();
    /// Nếu có dữ liệu máy truyền vào, thực hiện điền thông tin vào các ô nhập để chỉnh sửa.
    if (widget.phone != null) {
      _fillDataForEdit();
    }
    /// Tải danh sách hãng và danh mục sản phẩm từ hệ thống.
    _loadData();
  }

  /// Chức năng: Đổ dữ liệu từ Model sản phẩm hiện tại vào các ô nhập liệu (dùng khi sửa máy).
  void _fillDataForEdit() {
    _titleCtrl.text = widget.phone!.title;
    _descCtrl.text = widget.phone!.description;
    _priceCtrl.text = widget.phone!.price.toInt().toString();
    _stockCtrl.text = widget.phone!.stock.toString();
    _condition = widget.phone!.condition;
    _selectedBrandId = widget.phone!.brandId;
    _selectedCategoryId = widget.phone!.categoryId;

    _ramCtrl.text = _getOldSpec('RAM').replaceAll(' GB', '');
    _pinCtrl.text = _getOldSpec('Pin').replaceAll(' mAh', '');
    _screenCtrl.text = _getOldSpec('Màn hình');
    _storageCtrl.text = _getOldSpec('Bộ nhớ').replaceAll(' GB', '');
    _cpuCtrl.text = _getOldSpec('Chip');
  }

  /// Chức năng: Tìm kiếm giá trị thông số kỹ thuật dựa trên tên khóa (Key).
  String _getOldSpec(String key) {
    if (widget.phone == null) return "";
    try {
      return widget.phone!.specs.firstWhere((s) => s.key == key).value;
    } catch (_) {
      return "";
    }
  }

  /// Chức năng: Gọi API nạp đồng thời danh sách hãng và danh mục máy.
  Future<void> _loadData() async {
    try {
      // ✅ SỬA LỖI .data: ApiService trả về List nên gán trực tiếp
      final List<BrandModel> bRes = await _apiService.getBrands();
      final List<CategoryModel> cRes = await _apiService.getCategories();

      if (mounted) {
        setState(() {
          _brands = bRes;
          _categories = cRes;
          if (widget.phone == null) {
            if (_brands.isNotEmpty) _selectedBrandId = _brands.first.id;
            if (_categories.isNotEmpty) _selectedCategoryId = _categories.first.id;
          }
        });
      }
    } catch (e) {
      debugPrint("❌ Lỗi nạp dữ liệu: $e");
      Fluttertoast.showToast(msg: "Lỗi nạp danh mục");
    }
  }

  /// Chức năng: Hiển thị bảng chọn hãng sản xuất có tích hợp tính năng tìm kiếm và thêm mới.
  void _showBrandSearchDialog() {
    List<BrandModel> displayBrands = List.from(_brands);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.all(20),
                child: TextField(
                  controller: _searchBrandCtrl,
                  decoration: InputDecoration(
                    hintText: "Tìm tên hãng...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                  onChanged: (val) {
                    setModalState(() {
                      displayBrands = _brands.where((b) => b.name.toLowerCase().contains(val.toLowerCase())).toList();
                    });
                  },
                ),
              ),
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline, color: Colors.orange),
                      title: const Text("HÃNG KHÁC (THÊM MỚI)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      onTap: () {
                        setState(() {
                          _selectedBrandId = -1;
                          _isAddingNewBrand = true;
                        });
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(),
                    ...displayBrands.map((b) => ListTile(
                      title: Text(b.name),
                      trailing: _selectedBrandId == b.id ? const Icon(Icons.check_circle, color: Color(0xFF0047AB)) : null,
                      onTap: () {
                        setState(() {
                          _selectedBrandId = b.id;
                          _isAddingNewBrand = false;
                        });
                        Navigator.pop(context);
                      },
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Chức năng: Xử lý logic chọn ảnh từ thư viện.
  Future<void> _pickImage(bool isThumb) async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      if (isThumb) {
        final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 30);
        if (img != null) setState(() => _thumbnail = img);
      } else {
        final List<XFile> imgs = await _picker.pickMultiImage(imageQuality: 30);
        if (imgs.isNotEmpty) setState(() => _subImages.addAll(imgs));
      }
    } finally { if (mounted) setState(() => _isPickingImage = false); }
  }

  @override
  Widget build(BuildContext context) {
    final base = Provider.of<BaseProvider>(context);
    final px = base.textOffset;
    final isDark = base.isDarkMode;
    final theme = Theme.of(context);
    final bool isEdit = widget.phone != null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(isEdit ? "SỬA THÔNG TIN" : "ĐĂNG BÁN MÁY",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18 + px)),
        centerTitle: true, elevation: 0, backgroundColor: theme.cardColor,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildImageSection(px, theme, isDark),
            const SizedBox(height: 20),
            _buildCardWrapper(px, theme, isDark, "THÔNG TIN CHÍNH", [
              _buildInput(_titleCtrl, "Tên máy", px, theme, isDark, hint: "iPhone 15 Pro Max..."),
              _buildInput(_descCtrl, "Mô tả tình trạng", px, theme, isDark, maxLines: 3),
              Row(children: [
                Expanded(child: _buildInput(_priceCtrl, "Giá bán", px, theme, isDark, isNum: true, suffix: "đ")),
                const SizedBox(width: 12),
                Expanded(child: _buildInput(_stockCtrl, "Số lượng", px, theme, isDark, isNum: true)),
              ]),
              const SizedBox(height: 16),
              _buildBrandSelector(px, isDark),
              const SizedBox(height: 16),
              _buildCategoryDropdown(theme, isDark),
            ]),
            const SizedBox(height: 20),
            _buildCardWrapper(px, theme, isDark, "THÔNG SỐ KỸ THUẬT", [
              Row(children: [
                Expanded(child: _buildInput(_ramCtrl, "RAM", px, theme, isDark, isNum: true, suffix: "GB")),
                const SizedBox(width: 12),
                Expanded(child: _buildInput(_storageCtrl, "Bộ nhớ", px, theme, isDark, suffix: "GB")),
              ]),
              _buildInput(_pinCtrl, "Dung lượng Pin", px, theme, isDark, isNum: true, suffix: "mAh"),
              _buildInput(_screenCtrl, "Màn hình", px, theme, isDark, hint: "6.7 inch..."),
              _buildInput(_cpuCtrl, "Chip xử lý", px, theme, isDark),
            ]),
            const SizedBox(height: 20),
            _buildSectionTitle("TÌNH TRẠNG MÁY", px, isDark),
            _buildConditionChips(px, isDark),
            const SizedBox(height: 40),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0047AB),
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ),
                onPressed: _isSubmitting ? null : _submitData,
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isEdit ? "CẬP NHẬT THAY ĐỔI" : "XÁC NHẬN ĐĂNG BÁN",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16 + px))),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Hiển thị bộ chọn hãng sản xuất.
  Widget _buildBrandSelector(double px, bool isDark) {
    String brandName = "Chọn hãng máy";
    if (_selectedBrandId == -1) {
      brandName = "Hãng mới: ${_newBrandNameCtrl.text}";
    } else if (_selectedBrandId != null) {
      try {
        brandName = _brands.firstWhere((b) => b.id == _selectedBrandId).name;
      } catch (_) {}
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _showBrandSearchDialog,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(brandName, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14 + px)),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        ),
        if (_isAddingNewBrand) ...[
          const SizedBox(height: 12),
          _buildInput(_newBrandNameCtrl, "Tên hãng mới", px, Theme.of(context), isDark, hint: "Ví dụ: Bphone..."),
        ],
      ],
    );
  }

  /// Chức năng: Hiển thị dropdown chọn danh mục.
  Widget _buildCategoryDropdown(ThemeData theme, bool isDark) {
    return DropdownButtonFormField<int>(
      value: _selectedCategoryId,
      dropdownColor: theme.cardColor,
      decoration: InputDecoration(
          labelText: "Loại máy",
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
      ),
      items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
      onChanged: (v) => setState(() => _selectedCategoryId = v),
    );
  }

  /// Chức năng: Đóng gói và gửi dữ liệu lên Server.
  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.phone == null && _thumbnail == null) { Fluttertoast.showToast(msg: "Vui lòng chọn ảnh chính!"); return; }
    if (_selectedBrandId == null) { Fluttertoast.showToast(msg: "Vui lòng chọn hãng!"); return; }

    setState(() => _isSubmitting = true);
    final token = Provider.of<BaseProvider>(context, listen: false).token!;

    try {
      int? finalBrandId = _selectedBrandId;

      // Xử lý nếu người dùng thêm hãng mới
      if (_selectedBrandId == -1) {
        if (_newBrandNameCtrl.text.trim().isEmpty) throw "Vui lòng nhập tên hãng mới!";
        final Response bRes = await _apiService.storeBrand(_newBrandNameCtrl.text.trim(), token);
        if (bRes.data['success'] == true) {
          finalBrandId = bRes.data['data']['id'];
        } else {
          throw "Không thể tạo hãng mới!";
        }
      }

      final specs = [
        {'spec_key': 'RAM', 'spec_value': '${_ramCtrl.text} GB'},
        {'spec_key': 'Pin', 'spec_value': '${_pinCtrl.text} mAh'},
        {'spec_key': 'Màn hình', 'spec_value': _screenCtrl.text},
        {'spec_key': 'Bộ nhớ', 'spec_value': '${_storageCtrl.text} GB'},
        {'spec_key': 'Chip', 'spec_value': _cpuCtrl.text},
      ];

      final Map<String, dynamic> data = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'brand_id': finalBrandId.toString(),
        'category_id': _selectedCategoryId.toString(),
        'price': _priceCtrl.text.replaceAll(RegExp(r'[^0-9]'), ''),
        'stock': _stockCtrl.text,
        'condition': _condition,
        'specs': specs,
      };

      final res = widget.phone == null
          ? await _apiService.storePhoneWithImages(data: data, thumbnailPath: _thumbnail!.path, subImagePaths: _subImages.map((e) => e.path).toList(), token: token)
          : await _apiService.updatePhoneWithImages(id: widget.phone!.id, data: data, thumbnailPath: _thumbnail?.path, subImagePaths: _subImages.isEmpty ? null : _subImages.map((e) => e.path).toList(), token: token);

      if (res.data['success'] == true) {
        Fluttertoast.showToast(msg: "Thành công!");
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString(), backgroundColor: Colors.red);
    } finally { if (mounted) setState(() => _isSubmitting = false); }
  }

  /// Các Widget UI phụ trợ (Ảnh, Card, Input, Chips...)
  Widget _buildImageSection(double px, ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("ẢNH SẢN PHẨM", px, isDark),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _pickImage(true),
            child: Container(
              height: 180, width: double.infinity,
              decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: isDark ? Colors.white24 : Colors.grey[200]!)),
              child: _thumbnail != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(File(_thumbnail!.path), fit: BoxFit.cover))
                  : widget.phone != null
                  ? ClipRRect(borderRadius: BorderRadius.circular(15), child: ImageHelper.load(widget.phone!.thumbnailUrl))
                  : Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_a_photo, size: 40, color: Color(0xFF0047AB)), Text("Ảnh đại diện chính", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54))]),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _subImages.length + 1,
              itemBuilder: (ctx, index) {
                if (index == _subImages.length) {
                  return GestureDetector(
                    onTap: () => _pickImage(false),
                    child: Container(width: 80, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!)), child: const Icon(Icons.add_photo_alternate_outlined)),
                  );
                }
                return Stack(
                  children: [
                    Container(width: 80, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: FileImage(File(_subImages[index].path)), fit: BoxFit.cover))),
                    Positioned(right: 12, top: 4, child: GestureDetector(onTap: () => setState(() => _subImages.removeAt(index)), child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 12, color: Colors.white)))),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardWrapper(double px, ThemeData theme, bool isDark, String title, List<Widget> children) {
    return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.blueGrey[200] : Colors.blueGrey, fontSize: 13 + px)), Divider(height: 24, color: isDark ? Colors.white10 : Colors.grey[200]), ...children]));
  }

  Widget _buildInput(TextEditingController ctrl, String label, double px, ThemeData theme, bool isDark, {bool isNum = false, int maxLines = 1, String? suffix, String? hint}) {
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: TextFormField(controller: ctrl, maxLines: maxLines, keyboardType: isNum ? TextInputType.number : TextInputType.multiline, style: TextStyle(color: isDark ? Colors.white : Colors.black), decoration: InputDecoration(labelText: label, labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54), hintText: hint, hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38), suffixText: suffix, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50]), validator: (v) => (v == null || v.isEmpty) ? "Bắt buộc" : null));
  }

  Widget _buildConditionChips(double px, bool isDark) {
    final list = [{'v': 'new', 'l': 'MỚI'}, {'v': 'used', 'l': 'CŨ'}];
    return Wrap(spacing: 12, children: list.map((c) => ChoiceChip(label: Text(c['l']!, style: const TextStyle(fontWeight: FontWeight.bold)), selected: _condition == c['v'], selectedColor: const Color(0xFF0047AB), backgroundColor: isDark ? Colors.white10 : Colors.grey[200], labelStyle: TextStyle(color: _condition == c['v'] ? Colors.white : (isDark ? Colors.white70 : Colors.black)), onSelected: (_) => setState(() => _condition = c['v']!))).toList());
  }

  Widget _buildSectionTitle(String t, double px, bool isDark) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.blueGrey[100] : Colors.blueGrey, fontSize: 13 + px)));
}