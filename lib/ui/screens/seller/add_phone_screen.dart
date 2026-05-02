import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fluttertoast/fluttertoast.dart';
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
  final ImagePicker _picker = ImagePicker();

  /// Biểu thức chính quy dùng để lọc bỏ các ký tự không phải là số.
  static final RegExp _numericRegex = RegExp(r'[^0-9]');

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

  /// Chức năng: Giải phóng toàn bộ tài nguyên của các bộ điều khiển khi đóng màn hình.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _ramCtrl.dispose();
    _pinCtrl.dispose();
    _screenCtrl.dispose();
    _storageCtrl.dispose();
    _cpuCtrl.dispose();
    _searchBrandCtrl.dispose();
    super.dispose();
  }

  /// Chức năng: Đổ dữ liệu từ Model sản phẩm hiện tại vào các ô nhập liệu (dùng khi sửa máy).
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  void _fillDataForEdit() {
    final p = widget.phone!;
    _titleCtrl.text = p.title;
    _descCtrl.text = p.description;
    _priceCtrl.text = p.price.toInt().toString();
    _stockCtrl.text = p.stock.toString();
    _condition = p.condition;
    _selectedBrandId = p.brandId;
    _selectedCategoryId = p.categoryId;

    /// Xử lý tách đơn vị đo lường khỏi giá trị thông số để người dùng dễ chỉnh sửa số.
    _ramCtrl.text = _getOldSpec('RAM').replaceAll(' GB', '');
    _pinCtrl.text = _getOldSpec('Pin').replaceAll(' mAh', '');
    _screenCtrl.text = _getOldSpec('Màn hình');
    _storageCtrl.text = _getOldSpec('Bộ nhớ').replaceAll(' GB', '');
    _cpuCtrl.text = _getOldSpec('Chip');
  }

  /// Chức năng: Tìm kiếm giá trị thông số kỹ thuật dựa trên tên khóa (Key).
  /// Tham số đầu vào: [key] - Tên thông số cần lấy (RAM, Pin, ...).
  /// Giá trị trả về: Chuỗi giá trị của thông số hoặc chuỗi rỗng nếu không tìm thấy.
  String _getOldSpec(String key) {
    if (widget.phone == null) return "";
    try {
      return widget.phone!.specs.firstWhere((s) => s.key == key).value;
    } catch (_) { return ""; }
  }

  /// Chức năng: Gọi API nạp đồng thời danh sách hãng và danh mục máy để tối ưu tốc độ nạp trang.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void>.
  Future<void> _loadData() async {
    try {
      final api = context.read<BaseProvider>().apiService;

      /// Sử dụng Future.wait để thực hiện các yêu cầu nạp dữ liệu song song.
      final results = await Future.wait([
        api.getBrands(),
        api.getCategories(),
      ]);

      if (mounted) {
        setState(() {
          _brands = results[0] as List<BrandModel>;
          _categories = results[1] as List<CategoryModel>;

          /// Mặc định chọn các giá trị đầu tiên nếu là chế độ đăng máy mới.
          if (widget.phone == null) {
            if (_brands.isNotEmpty) _selectedBrandId = _brands.first.id;
            if (_categories.isNotEmpty) _selectedCategoryId = _categories.first.id;
          }
        });
      }
    } catch (e) {
      debugPrint("❌ Lỗi nạp dữ liệu: $e");
    }
  }

  /// Chức năng: Hiển thị bảng chọn hãng sản xuất có tích hợp tính năng tìm kiếm nhanh.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  void _showBrandSearchDialog() {
    List<BrandModel> displayBrands = List.from(_brands);
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, setModalState) => Container(
                height: MediaQuery.of(ctx).size.height * 0.7,
                decoration: BoxDecoration(
                    color: Theme.of(ctx).cardColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30))
                ),
                child: Column(children: [
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)
                          ),
                          /// Cập nhật danh sách hiển thị ngay khi người dùng gõ tìm kiếm.
                          onChanged: (val) => setModalState(() => displayBrands = _brands.where((b) => b.name.toLowerCase().contains(val.toLowerCase())).toList())
                      )
                  ),
                  Expanded(child: ListView.builder(
                    itemCount: displayBrands.length,
                    itemBuilder: (ctx, i) {
                      final b = displayBrands[i];
                      return ListTile(
                          title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          trailing: _selectedBrandId == b.id ? const Icon(Icons.check_circle, color: Color(0xFF0047AB)) : null,
                          onTap: () {
                            setState(() { _selectedBrandId = b.id; });
                            Navigator.pop(ctx);
                          }
                      );
                    },
                  )),
                ]))));
  }

  @override
  Widget build(BuildContext context) {
    /// Lắng nghe chọn lọc các thay đổi về giao diện (Dark Mode) và cấu hình cỡ chữ.
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);
    final px = context.select<BaseProvider, double>((p) => p.textOffset);
    final theme = Theme.of(context);
    final bool isEdit = widget.phone != null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
      appBar: AppBar(
          title: Text(isEdit ? "SỬA THÔNG TIN" : "ĐĂNG BÁN MÁY",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18 + px)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: theme.cardColor
      ),
      body: Form(
          key: _formKey,
          child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                /// Khu vực chọn và hiển thị hình ảnh máy.
                _buildImageSection(px, theme, isDark),
                const SizedBox(height: 20),
                /// Khu vực nhập thông tin cơ bản: Tên, mô tả, giá, hãng, danh mục.
                _buildCardWrapper(px, theme, isDark, "THÔNG TIN CHÍNH", [
                  _buildInput(_titleCtrl, "Tên máy", px, isDark, hint: "iPhone 15 Pro Max...", action: TextInputAction.next),
                  _buildInput(_descCtrl, "Mô tả tình trạng", px, isDark, maxLines: 3),
                  Row(children: [
                    Expanded(child: _buildInput(_priceCtrl, "Giá bán", px, isDark, isNum: true, suffix: "đ", action: TextInputAction.next)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInput(_stockCtrl, "Số lượng", px, isDark, isNum: true, action: TextInputAction.next)),
                  ]),
                  const SizedBox(height: 16),
                  _buildBrandSelector(px, isDark),
                  const SizedBox(height: 16),
                  _buildCategoryDropdown(theme, isDark, px),
                ]),
                const SizedBox(height: 20),
                /// Khu vực nhập thông số kỹ thuật chi tiết.
                _buildCardWrapper(px, theme, isDark, "THÔNG SỐ KỸ THUẬT", [
                  Row(children: [
                    Expanded(child: _buildInput(_ramCtrl, "RAM", px, isDark, isNum: true, suffix: "GB", action: TextInputAction.next)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildInput(_storageCtrl, "Bộ nhớ", px, isDark, suffix: "GB", action: TextInputAction.next)),
                  ]),
                  _buildInput(_pinCtrl, "Dung lượng Pin", px, isDark, isNum: true, suffix: "mAh", action: TextInputAction.next),
                  _buildInput(_screenCtrl, "Màn hình", px, isDark, hint: "6.7 inch...", action: TextInputAction.next),
                  _buildInput(_cpuCtrl, "Chip xử lý", px, isDark, action: TextInputAction.done),
                ]),
                const SizedBox(height: 20),
                _buildSectionTitle("TÌNH TRẠNG MÁY", px, isDark),
                _buildConditionChips(isDark),
                const SizedBox(height: 40),
                /// Nút bấm gửi dữ liệu lên server.
                _buildSubmitButton(isEdit, px),
                const SizedBox(height: 50),
              ]
          )
      ),
    );
  }

  /// Chức năng: Xây dựng giao diện nút bấm để mở bảng chọn hãng máy.
  Widget _buildBrandSelector(double px, bool isDark) {
    final BrandModel selectedBrand = _brands.firstWhere(
            (b) => b.id == _selectedBrandId,
        orElse: () => BrandModel(id: 0, name: 'Chọn hãng máy')
    );

    return InkWell(
        onTap: _showBrandSearchDialog,
        borderRadius: BorderRadius.circular(12),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!)
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(selectedBrand.name, style: TextStyle(fontSize: 14 + px)),
                  const Icon(Icons.arrow_drop_down)
                ]
            )
        )
    );
  }

  /// Chức năng: Xây dựng danh sách thả chọn cho danh mục sản phẩm (Loại máy).
  Widget _buildCategoryDropdown(ThemeData theme, bool isDark, double px) {
    return DropdownButtonFormField<int>(
        value: _selectedCategoryId,
        dropdownColor: theme.cardColor,
        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14 + px),
        decoration: InputDecoration(
            labelText: "Loại máy",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
        ),
        items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
        onChanged: (v) => setState(() => _selectedCategoryId = v)
    );
  }

  /// Chức năng: Xử lý đóng gói dữ liệu và gửi yêu cầu Lưu (Thêm mới/Cập nhật) sản phẩm lên API Laravel.
  /// Tham số đầu vào: Không có (Sử dụng dữ liệu từ Controller).
  /// Giá trị trả về: Future<void>.
  Future<void> _submitData() async {
    /// Kiểm tra tính hợp lệ của toàn bộ form trước khi gửi.
    if (!_formKey.currentState!.validate()) return;
    if (widget.phone == null && _thumbnail == null) { Fluttertoast.showToast(msg: "Vui lòng chọn ảnh!"); return; }
    if (_selectedBrandId == null) { Fluttertoast.showToast(msg: "Vui lòng chọn hãng!"); return; }

    setState(() => _isSubmitting = true);
    final base = context.read<BaseProvider>();

    try {
      /// Chuẩn bị danh sách thông số kỹ thuật đính kèm đơn vị.
      final specs = [
        {'spec_key': 'RAM', 'spec_value': '${_ramCtrl.text.trim()} GB'},
        {'spec_key': 'Pin', 'spec_value': '${_pinCtrl.text.trim()} mAh'},
        {'spec_key': 'Màn hình', 'spec_value': _screenCtrl.text.trim()},
        {'spec_key': 'Bộ nhớ', 'spec_value': '${_storageCtrl.text.trim()} GB'},
        {'spec_key': 'Chip', 'spec_value': _cpuCtrl.text.trim()},
      ];

      /// Khởi tạo bản đồ dữ liệu JSON để gửi lên máy chủ.
      final Map<String, dynamic> data = {
        'title': _titleCtrl.text.trim(),
        'brand_id': _selectedBrandId.toString(),
        'category_id': _selectedCategoryId.toString(),
        'price': _priceCtrl.text.replaceAll(_numericRegex, ''),
        'stock': _stockCtrl.text.trim(),
        'condition': _condition,
        'specs': specs,
        'description': _descCtrl.text.trim(),
      };

      /// Quyết định gọi hàm Thêm mới hay Cập nhật tùy thuộc vào việc có truyền Model phone vào không.
      final res = widget.phone == null
          ? await base.apiService.storePhoneWithImages(
          data: data,
          thumbnailPath: _thumbnail!.path,
          subImagePaths: _subImages.map((e) => e.path).toList(),
          token: base.token!
      )
          : await base.apiService.updatePhoneWithImages(
          id: widget.phone!.id,
          data: data,
          thumbnailPath: _thumbnail?.path,
          subImagePaths: _subImages.isEmpty ? null : _subImages.map((e) => e.path).toList(),
          token: base.token!
      );

      if (res.data['success']) {
        Fluttertoast.showToast(msg: "Thành công!");
        if (mounted) Navigator.pop(context, true);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Lỗi lưu dữ liệu");
    } finally {
      if(mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Chức năng: Xử lý logic chọn ảnh đại diện chính hoặc nhiều ảnh phụ từ thư viện thiết bị.
  /// Tham số đầu vào: [isThumb] - Đúng nếu là ảnh đại diện chính, Sai nếu là ảnh mô tả phụ.
  /// Giá trị trả về: Future<void>.
  Future<void> _pickImage(bool isThumb) async {
    if (_isPickingImage) return;
    setState(() => _isPickingImage = true);
    try {
      if (isThumb) {
        final img = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
        if (img != null) setState(() => _thumbnail = img);
      } else {
        final List<XFile> imgs = await _picker.pickMultiImage(imageQuality: 80);
        if (imgs.isNotEmpty) setState(() => _subImages.addAll(imgs));
      }
    } finally { if (mounted) setState(() => _isPickingImage = false); }
  }

  /// Chức năng: Xây dựng khu vực hiển thị và quản lý hình ảnh sản phẩm.
  Widget _buildImageSection(double px, ThemeData theme, bool isDark) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10)]
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionTitle("ẢNH SẢN PHẨM", px, isDark),
          const SizedBox(height: 12),
          /// Ô chọn ảnh đại diện chính của sản phẩm.
          GestureDetector(
              onTap: () => _pickImage(true),
              child: Container(
                  height: 180, width: double.infinity,
                  decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey[50],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: isDark ? Colors.white24 : Colors.grey[200]!)
                  ),
                  child: _thumbnail != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(File(_thumbnail!.path), fit: BoxFit.cover))
                      : widget.phone != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(15), child: ImageHelper.load(widget.phone!.thumbnailUrl))
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.add_a_photo, size: 40, color: Color(0xFF0047AB)),
                    Text("Ảnh đại diện chính", style: TextStyle(color: isDark ? Colors.white70 : Colors.black54))
                  ])
              )
          ),
          const SizedBox(height: 16),
          /// Danh sách trượt ngang hiển thị các ảnh mô tả phụ đã chọn.
          SizedBox(
              height: 80,
              child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  cacheExtent: 300,
                  itemCount: _subImages.length + 1,
                  itemBuilder: (ctx, index) {
                    /// Mục cuối cùng trong danh sách là nút bấm để chọn thêm ảnh phụ.
                    if (index == _subImages.length) {
                      return GestureDetector(
                          onTap: () => _pickImage(false),
                          child: Container(
                              width: 80, margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], borderRadius: BorderRadius.circular(10), border: Border.all(color: isDark ? Colors.white24 : Colors.grey[300]!)),
                              child: const Icon(Icons.add_photo_alternate_outlined)
                          )
                      );
                    }
                    /// Hiển thị ảnh phụ kèm nút xóa nhanh cho từng ảnh.
                    return Stack(children: [
                      Container(width: 80, margin: const EdgeInsets.only(right: 8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: FileImage(File(_subImages[index].path)), fit: BoxFit.cover))),
                      Positioned(right: 12, top: 4, child: GestureDetector(onTap: () => setState(() => _subImages.removeAt(index)), child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 12, color: Colors.white))))
                    ]);
                  }
              )
          ),
        ]));
  }

  /// Chức năng: Tạo khung bao bọc (Card) cho từng nhóm thông tin để đồng nhất giao diện Minimalism.
  Widget _buildCardWrapper(double px, ThemeData theme, bool isDark, String title, List<Widget> children) {
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10)]
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.blueGrey[200] : Colors.blueGrey, fontSize: 13 + px)),
              Divider(height: 24, color: isDark ? Colors.white10 : Colors.grey[200]),
              ...children
            ]
        )
    );
  }

  /// Chức năng: Tạo ô nhập liệu chuẩn (TextFormField) cho toàn bộ form.
  /// Tham số đầu vào: [ctrl], [label], [px], [isDark], các cấu hình bàn phím và nhãn gợi ý.
  Widget _buildInput(TextEditingController ctrl, String label, double px, bool isDark, {bool isNum = false, int maxLines = 1, String? suffix, String? hint, TextInputAction? action}) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
            controller: ctrl,
            maxLines: maxLines,
            textInputAction: action,
            keyboardType: isNum ? TextInputType.number : TextInputType.multiline,
            style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14 + px),
            decoration: InputDecoration(
                labelText: label,
                labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 14 + px),
                hintText: hint,
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                suffixText: suffix,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50]
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? "Bắt buộc" : null
        )
    );
  }

  /// Chức năng: Xây dựng bộ nút lựa chọn tình trạng máy (Mới/Cũ).
  Widget _buildConditionChips(bool isDark) {
    final list = [{'v': 'new', 'l': 'MỚI'}, {'v': 'used', 'l': 'CŨ'}];
    return Wrap(
        spacing: 12,
        children: list.map((c) => ChoiceChip(
            label: Text(c['l']!, style: const TextStyle(fontWeight: FontWeight.bold)),
            selected: _condition == c['v'],
            selectedColor: const Color(0xFF0047AB),
            backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
            labelStyle: TextStyle(color: _condition == c['v'] ? Colors.white : (isDark ? Colors.white70 : Colors.black)),
            onSelected: (_) => setState(() => _condition = c['v']!)
        )).toList()
    );
  }

  /// Chức năng: Hiển thị tiêu đề cho từng phân đoạn nhỏ trong trang.
  Widget _buildSectionTitle(String t, double px, bool isDark) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.blueGrey[100] : Colors.blueGrey, fontSize: 13 + px))
  );

  /// Chức năng: Xây dựng nút bấm chính để thực hiện đăng tin hoặc cập nhật.
  Widget _buildSubmitButton(bool isEdit, double px) {
    return ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0047AB),
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 0,
        ),
        /// Vô hiệu hóa nút khi đang trong quá trình nộp dữ liệu.
        onPressed: _isSubmitting ? null : _submitData,
        child: _isSubmitting
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(isEdit ? "CẬP NHẬT THAY ĐỔI" : "XÁC NHẬN ĐĂNG BÁN",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16 + px))
    );
  }
}