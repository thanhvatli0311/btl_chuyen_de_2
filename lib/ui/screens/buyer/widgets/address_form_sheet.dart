import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../data/models/address_model.dart';
import '../../../../providers/address_provider.dart';
import '../../../../providers/base_provider.dart';

class AddressFormSheet extends StatefulWidget {
  final AddressModel? address;
  const AddressFormSheet({super.key, this.address});

  @override
  State<AddressFormSheet> createState() => _AddressFormSheetState();
}

class _AddressFormSheetState extends State<AddressFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _provinceController;
  late TextEditingController _districtController;
  late TextEditingController _wardController;
  late TextEditingController _detailController;
  bool _isDefault = false;

  /// Chức năng: Khởi tạo trạng thái ban đầu cho các ô nhập liệu (Form)
  /// Tham số đầu vào: Không có
  /// Giá trị trả về: Không có
  @override
  void initState() {
    super.initState();
    /// Nếu đang ở chế độ chỉnh sửa (address != null), gán giá trị cũ vào các controller
    _nameController = TextEditingController(text: widget.address?.recipientName);
    _phoneController = TextEditingController(text: widget.address?.phone);
    _provinceController = TextEditingController(text: widget.address?.province ?? "Hà Nội");
    _districtController = TextEditingController(text: widget.address?.district ?? "Cầu Giấy");
    _wardController = TextEditingController(text: widget.address?.ward ?? "Dịch Vọng");
    _detailController = TextEditingController(text: widget.address?.detail);
    _isDefault = widget.address?.isDefault ?? false;
  }

  /// Chức năng: Giải phóng tài nguyên hệ thống khi đóng form
  /// Tham số đầu vào: Không có
  /// Giá trị trả về: Không có
  @override
  void dispose() {
    /// Hủy toàn bộ các controller để tránh rò rỉ bộ nhớ (Memory Leak)
    _nameController.dispose();
    _phoneController.dispose();
    _provinceController.dispose();
    _districtController.dispose();
    _wardController.dispose();
    _detailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /// Sử dụng context.select để chỉ vẽ lại widget khi các giá trị cần thiết thực sự thay đổi
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);
    final token = context.select<BaseProvider, String?>((p) => p.token);
    final px = context.select<BaseProvider, double>((p) => p.textOffset);

    return Container(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20, right: 20, top: 20
      ),
      decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25))
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                  widget.address == null ? "THÊM ĐỊA CHỈ MỚI" : "CHỈNH SỬA ĐỊA CHỈ",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 + px)
              ),
              const SizedBox(height: 20),

              _buildField("Họ và tên", _nameController, Icons.person_outline, isDark, px, action: TextInputAction.next),
              _buildField("Số điện thoại", _phoneController, Icons.phone_android_outlined, isDark, px, keyboard: TextInputType.phone, action: TextInputAction.next),

              Row(
                children: [
                  Expanded(child: _buildField("Tỉnh/TP", _provinceController, Icons.map_outlined, isDark, px, action: TextInputAction.next)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildField("Quận/Huyện", _districtController, Icons.location_city, isDark, px, action: TextInputAction.next)),
                ],
              ),

              _buildField("Phường/Xã", _wardController, Icons.holiday_village_outlined, isDark, px, action: TextInputAction.next),
              _buildField("Số nhà, tên đường...", _detailController, Icons.home_outlined, isDark, px, action: TextInputAction.done),

              SwitchListTile(
                title: Text("Đặt làm địa chỉ mặc định", style: TextStyle(fontSize: 14 + px)),
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                activeColor: Colors.blueAccent,
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),

              Consumer<AddressProvider>(
                builder: (context, addrProv, _) => ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 55),
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  onPressed: addrProv.isLoading ? null : () async {
                    /// Kiểm tra tính hợp lệ của toàn bộ form trước khi gửi dữ liệu
                    if (_formKey.currentState!.validate()) {
                      final data = {
                        'recipient_name': _nameController.text.trim(),
                        'phone': _phoneController.text.trim(),
                        'province': _provinceController.text.trim(),
                        'district': _districtController.text.trim(),
                        'ward': _wardController.text.trim(),
                        'detail': _detailController.text.trim(),
                        'is_default': _isDefault ? 1 : 0,
                      };

                      bool success;
                      /// Phân biệt logic Thêm mới hoặc Cập nhật dựa trên tham số address
                      if (widget.address == null) {
                        success = await addrProv.addAddress(token!, data);
                      } else {
                        success = await addrProv.updateAddress(token!, widget.address!.id, data);
                      }

                      /// Kiểm tra mounted để đảm bảo widget vẫn còn tồn tại trước khi điều hướng quay lại
                      if (success && mounted) Navigator.pop(context);
                    }
                  },
                  child: addrProv.isLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text("LƯU ĐỊA CHỈ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15 + px)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  /// Chức năng: Tạo ra các ô nhập liệu (TextFormField) với giao diện đồng nhất
  /// Tham số đầu vào: [label] nhãn hiển thị, [ctrl] bộ điều khiển văn bản, [icon] biểu tượng minh họa,
  /// [isDark] chế độ tối, [px] độ lệch cỡ chữ, [keyboard] kiểu bàn phím, [action] hành động khi nhấn nút trên bàn phím.
  /// Giá trị trả về: Một Widget TextFormField được bọc trong Padding
  Widget _buildField(String label, TextEditingController ctrl, IconData icon, bool isDark, double px, {TextInputType? keyboard, TextInputAction? action}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        textInputAction: action,
        style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14 + px),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 14 + px),
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        /// Logic kiểm tra cơ bản: Không cho phép để trống nội dung
        validator: (v) => (v == null || v.trim().isEmpty) ? "Không được để trống" : null,
      ),
    );
  }
}