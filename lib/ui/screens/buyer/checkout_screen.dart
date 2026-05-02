import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/address_provider.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/base_provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  /// Bộ định dạng tiền tệ Việt Nam dùng chung.
  /// Sử dụng static final để khởi tạo một lần duy nhất, tránh gây tốn tài nguyên CPU khi màn hình vẽ lại.
  static final NumberFormat _currency = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);

  String _selectedPaymentMethod = 'cod';
  String _currentProvince = "";
  String _currentDistrict = "";
  String _currentWard = "";

  /// Chức năng: Khởi tạo dữ liệu và nạp địa chỉ mặc định ngay khi vào màn hình.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  @override
  void initState() {
    super.initState();
    /// Đợi khung hình đầu tiên dựng xong để đảm bảo Context đã sẵn sàng.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final base = context.read<BaseProvider>();
      final addrProv = context.read<AddressProvider>();

      /// Tự động điền thông tin cá nhân của người dùng hiện tại vào form.
      if (base.user != null) {
        _nameController.text = base.user!.name ?? "";
        _phoneController.text = base.user!.phone ?? "";

        /// Tải danh sách địa chỉ từ máy chủ và tìm địa chỉ được đặt làm mặc định.
        await addrProv.fetchAddresses(base.token!);
        final defaultAddr = addrProv.getDefaultAddress();

        /// Nếu có địa chỉ mặc định, cập nhật trạng thái UI để hiển thị.
        if (defaultAddr != null && mounted) {
          setState(() {
            _addressController.text = defaultAddr.detail;
            _currentProvince = defaultAddr.province;
            _currentDistrict = defaultAddr.district;
            _currentWard = defaultAddr.ward;
          });
        }
      }
    });
  }

  /// Chức năng: Giải phóng các bộ điều khiển văn bản khi màn hình bị đóng.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    /// Lắng nghe thay đổi cụ thể từ giỏ hàng thông qua context.select để tối ưu hiệu năng render.
    final cartItems = context.select<CartProvider, List>((p) => p.items);
    final totalAmount = context.select<CartProvider, double>((p) => p.totalSelectedAmount);

    final base = context.read<BaseProvider>();
    final isDark = base.isDarkMode;
    final px = base.textOffset;

    /// Lọc ra danh sách các món hàng đã được người dùng tích chọn trong giỏ hàng.
    final selectedItems = cartItems.where((e) => e.isSelected).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Text("Thanh toán",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 + px)),
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSectionCard(isDark, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Thông tin giao hàng",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15 + px)),
                    TextButton.icon(
                      onPressed: () => _showSavedAddresses(context),
                      icon: const Icon(Icons.history, size: 16),
                      label: Text("Sổ địa chỉ", style: TextStyle(fontSize: 12 + px)),
                    ),
                  ],
                ),
                const Divider(),
                _buildTextField("Họ và tên người nhận", _nameController, Icons.person_outline, px),
                _buildTextField("Số điện thoại", _phoneController, Icons.phone_android_outlined, px),

                const SizedBox(height: 10),

                InkWell(
                  onTap: () => _showStructuredAddressForm(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.blueAccent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _addressController.text.isEmpty
                                    ? "Bấm để nhập địa chỉ giao hàng"
                                    : "Địa chỉ chi tiết: ${_addressController.text}",
                                style: TextStyle(
                                    fontWeight: _addressController.text.isEmpty ? FontWeight.normal : FontWeight.bold,
                                    fontSize: 14 + px,
                                    color: _addressController.text.isEmpty ? Colors.grey : (isDark ? Colors.white : Colors.black)
                                ),
                              ),
                              if (_currentProvince.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    "Khu vực: $_currentWard, $_currentDistrict, $_currentProvince",
                                    style: TextStyle(fontSize: 12 + px, color: Colors.blueAccent),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_note, color: Colors.grey, size: 20),
                      ],
                    ),
                  ),
                ),
              ],
            )),
            const SizedBox(height: 16),

            _buildSectionCard(isDark, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Phương thức thanh toán",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15 + px)),
                const Divider(),
                _buildPaymentOption('cod', "Thanh toán khi nhận hàng (COD)", Icons.payments_outlined, px),
                _buildPaymentOption('bank_transfer', "Chuyển khoản ngân hàng", Icons.account_balance_outlined, px),
              ],
            )),

            const SizedBox(height: 16),

            _buildSectionCard(isDark, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Sản phẩm đã chọn",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px)),
                const SizedBox(height: 12),
                ...selectedItems.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text("${item.quantity}x ",
                          style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13 + px)),
                      Expanded(
                          child: Text(item.phone.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13 + px))
                      ),
                      Text(_currency.format((item.phone.discountPrice ?? item.phone.price) * item.quantity),
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13 + px)),
                    ],
                  ),
                )),
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Tổng thanh toán",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15 + px)),
                    Text(_currency.format(totalAmount),
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18 + px)),
                  ],
                ),
              ],
            )),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomAction(context, isDark, px),
    );
  }

  /// Chức năng: Xây dựng ô nhập liệu văn bản chuẩn cho trang thanh toán.
  /// Tham số đầu vào: [label] nhãn ô nhập, [controller] bộ điều khiển, [icon] biểu tượng, [px] độ lệch cỡ chữ.
  /// Giá trị trả về: Widget dạng Padding chứa TextField.
  Widget _buildTextField(String label, TextEditingController controller, IconData icon, double px) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        style: TextStyle(fontSize: 14 + px),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.grey.withOpacity(0.08),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  /// Chức năng: Xây dựng một tùy chọn thanh toán đơn lẻ (Radio button).
  /// Tham số đầu vào: [value] giá trị mã, [title] nhãn hiển thị, [icon] biểu tượng minh họa, [px] cỡ chữ.
  /// Giá trị trả về: Widget RadioListTile.
  Widget _buildPaymentOption(String value, String title, IconData icon, double px) {
    return RadioListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      groupValue: _selectedPaymentMethod,
      title: Text(title, style: TextStyle(fontSize: 14 + px)),
      secondary: Icon(icon, size: 20),
      activeColor: const Color(0xFF0047AB),
      onChanged: (val) => setState(() => _selectedPaymentMethod = val.toString()),
    );
  }

  /// Chức năng: Tạo khung chứa (Card) phân đoạn cho các phần thông tin khác nhau.
  /// Tham số đầu vào: [isDark] chế độ tối, [child] nội dung bên trong khung.
  /// Giá trị trả về: Widget Container có trang trí bóng đổ.
  Widget _buildSectionCard(bool isDark, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10)],
      ),
      child: child,
    );
  }

  /// Chức năng: Xây dựng nút xác nhận đặt hàng và xử lý logic gửi dữ liệu lên server.
  /// Tham số đầu vào: [context], [isDark], [px].
  /// Giá trị trả về: Widget thanh điều hướng dưới cùng (BottomNavigationBar).
  Widget _buildBottomAction(BuildContext context, bool isDark, double px) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: SafeArea(
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0047AB),
            minimumSize: const Size(double.infinity, 55),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          onPressed: () async {
            final cartProv = context.read<CartProvider>();
            final base = context.read<BaseProvider>();

            /// Lấy danh sách ID của các món đồ được chọn để tiến hành checkout.
            final selectedCartIds = cartProv.items
                .where((e) => e.isSelected)
                .map((e) => e.id)
                .toList();

            /// Ràng buộc người dùng phải chọn địa chỉ trước khi đặt hàng.
            if (_addressController.text.isEmpty || _currentProvince.isEmpty) {
              Fluttertoast.showToast(msg: "Vui lòng chọn địa chỉ giao hàng!");
              return;
            }

            /// Đóng gói toàn bộ dữ liệu đơn hàng theo yêu cầu của API Laravel.
            Map<String, dynamic> checkoutData = {
              'name': _nameController.text,
              'phone': _phoneController.text,
              'address': _addressController.text,
              'province': _currentProvince,
              'district': _currentDistrict,
              'ward': _currentWard,
              'payment_method': _selectedPaymentMethod,
              'cart_ids': selectedCartIds,
              'total_price': cartProv.totalSelectedAmount,
            };

            /// Hiển thị vòng xoay chờ xử lý và gọi API tạo đơn hàng.
            _showLoading();
            bool success = await cartProv.processCheckout(base.token!, checkoutData);

            /// Đóng vòng xoay chờ sau khi nhận phản hồi.
            if (mounted) Navigator.pop(context);

            /// Hiển thị thông báo kết quả cuối cùng cho người dùng.
            if (success) {
              _showSuccess(context);
            } else {
              Fluttertoast.showToast(
                  msg: cartProv.lastErrorMessage ?? "Lỗi đặt hàng",
                  backgroundColor: Colors.red
              );
            }
          },
          child: Text("XÁC NHẬN ĐẶT HÀNG",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15 + px)),
        ),
      ),
    );
  }

  /// Chức năng: Hiển thị bảng chọn từ danh sách địa chỉ đã lưu trong sổ địa chỉ.
  /// Tham số đầu vào: [context].
  /// Giá trị trả về: Không có (Mở BottomSheet).
  void _showSavedAddresses(BuildContext context) {
    final addrProv = context.read<AddressProvider>();
    final isDark = context.read<BaseProvider>().isDarkMode;
    final px = context.read<BaseProvider>().textOffset;

    if (addrProv.addresses.isEmpty) {
      Fluttertoast.showToast(msg: "Ông chưa có địa chỉ nào trong sổ!");
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text("CHỌN ĐỊA CHỈ GIAO HÀNG",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 + px)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: addrProv.addresses.length,
                itemBuilder: (context, index) {
                  final addr = addrProv.addresses[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    leading: Icon(Icons.location_on, color: addr.isDefault ? Colors.blue : Colors.grey),
                    title: Text(addr.recipientName,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 + px)),
                    subtitle: Text(
                      "${addr.phone}\n${addr.detail}, ${addr.ward}, ${addr.district}, ${addr.province}",
                      style: TextStyle(fontSize: 12 + px),
                    ),
                    isThreeLine: true,
                    onTap: () {
                      /// Tự động điền nhanh dữ liệu từ địa chỉ đã chọn vào trang thanh toán.
                      setState(() {
                        _nameController.text = addr.recipientName;
                        _phoneController.text = addr.phone;
                        _addressController.text = addr.detail;
                        _currentProvince = addr.province;
                        _currentDistrict = addr.district;
                        _currentWard = addr.ward;
                      });
                      Navigator.pop(context);
                      Fluttertoast.showToast(msg: "Đã áp dụng!");
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chức năng: Hiển thị hộp thoại vòng xoay không thể bị đóng khi đang thực hiện giao dịch.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Không có.
  void _showLoading() => showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator())
  );

  /// Chức năng: Hiển thị thông báo đặt hàng thành công và điều hướng về trang chủ.
  /// Tham số đầu vào: [context].
  /// Giá trị trả về: Không có.
  void _showSuccess(BuildContext context) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Column(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 60),
              SizedBox(height: 10),
              Text("Thành công!"),
            ],
          ),
          content: const Text("Đơn hàng của bạn đã được gửi đến Shop.", textAlign: TextAlign.center),
          actions: [
            Center(
              child: ElevatedButton(
                /// Xóa toàn bộ lịch sử các trang đã mở và đưa người dùng về trang màn hình chính.
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text("TIẾP TỤC MUA SẮM"),
              ),
            )
          ],
        )
    );
  }

  /// Chức năng: Hiển thị bảng nhập liệu địa chỉ chi tiết theo từng cấp bậc hành chính.
  /// Tham số đầu vào: [context].
  /// Giá trị trả về: Không có.
  void _showStructuredAddressForm(BuildContext context) {
    final isDark = context.read<BaseProvider>().isDarkMode;
    final px = context.read<BaseProvider>().textOffset;

    /// Tạo bộ điều khiển tạm thời để lưu trữ dữ liệu người dùng đang gõ trong Modal.
    final tempAddressCtrl = TextEditingController(text: _addressController.text);
    final tempProvinceCtrl = TextEditingController(text: _currentProvince);
    final tempDistrictCtrl = TextEditingController(text: _currentDistrict);
    final tempWardCtrl = TextEditingController(text: _currentWard);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20, right: 20, top: 20
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("NHẬP ĐỊA CHỈ GIAO HÀNG",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15 + px)),
              const SizedBox(height: 20),
              _buildModalField("Tỉnh/Thành phố", tempProvinceCtrl, Icons.map, isDark, px),
              _buildModalField("Quận/Huyện", tempDistrictCtrl, Icons.location_city, isDark, px),
              _buildModalField("Phường/Xã", tempWardCtrl, Icons.holiday_village, isDark, px),
              _buildModalField("Số nhà, tên đường...", tempAddressCtrl, Icons.home, isDark, px),

              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  /// Cập nhật kết quả từ bảng nhập vào biến trạng thái của màn hình chính.
                  setState(() {
                    _addressController.text = tempAddressCtrl.text;
                    _currentProvince = tempProvinceCtrl.text;
                    _currentDistrict = tempDistrictCtrl.text;
                    _currentWard = tempWardCtrl.text;
                  });
                  Navigator.pop(context);
                },
                child: Text("XÁC NHẬN ĐỊA CHỈ",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14 + px)),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  /// Chức năng: Xây dựng ô nhập liệu đơn lẻ bên trong hộp thoại địa chỉ.
  /// Tham số đầu vào: [label], [ctrl], [icon], [isDark], [px].
  /// Giá trị trả về: Widget dạng Padding chứa TextField.
  Widget _buildModalField(String label, TextEditingController ctrl, IconData icon, bool isDark, double px) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        style: TextStyle(fontSize: 14 + px),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          filled: true,
          fillColor: isDark ? Colors.white10 : Colors.grey[100],
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}