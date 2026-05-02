import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/models/address_model.dart';
import '../../../providers/address_provider.dart';
import '../../../providers/base_provider.dart';
import 'widgets/address_form_sheet.dart';

class AddressListScreen extends StatefulWidget {
  const AddressListScreen({super.key});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  @override
  void initState() {
    super.initState();
    /// Chức năng: Khởi tạo và nạp danh sách địa chỉ ngay khi vào màn hình.
    /// Logic: Sử dụng addPostFrameCallback để đảm bảo Context đã sẵn sàng trước khi gọi Provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<BaseProvider>().token;
      if (token != null) {
        context.read<AddressProvider>().fetchAddresses(token);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    /// Lắng nghe thay đổi chọn lọc từ BaseProvider để tối ưu hóa hiệu năng render.
    final token = context.select<BaseProvider, String?>((p) => p.token);
    final isDark = context.select<BaseProvider, bool>((p) => p.isDarkMode);
    final px = context.select<BaseProvider, double>((p) => p.textOffset);

    /// Lắng nghe trạng thái dữ liệu từ AddressProvider.
    final isLoading = context.select<AddressProvider, bool>((p) => p.isLoading);
    final addresses = context.select<AddressProvider, List<AddressModel>>((p) => p.addresses);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Text("SỔ ĐỊA CHỈ",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16 + px)),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : addresses.isEmpty
          ? const Center(child: Text("Chưa có địa chỉ nào.", style: TextStyle(color: Colors.grey)))
          : RefreshIndicator(
        /// Chức năng: Cho phép người dùng kéo xuống để cập nhật lại danh sách địa chỉ.
        onRefresh: () => context.read<AddressProvider>().fetchAddresses(token!),
        child: ListView.builder(
          /// Cấu hình vùng đệm để tối ưu hóa hiệu năng cuộn mượt mà trên các dòng máy Android.
          cacheExtent: 500,
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: addresses.length,
          itemBuilder: (context, index) {
            return _buildAddressCard(addresses[index], isDark, px);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openForm(context),
        backgroundColor: const Color(0xFF0047AB),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// Chức năng: Xây dựng giao diện thẻ hiển thị thông tin chi tiết từng địa chỉ.
  /// Tham số đầu vào: [addr] (Dữ liệu địa chỉ), [isDark] (Chế độ tối), [px] (Độ lệch cỡ chữ).
  /// Giá trị trả về: Widget dạng Container chứa thông tin địa chỉ.
  Widget _buildAddressCard(AddressModel addr, bool isDark, double px) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        /// Làm nổi bật địa chỉ được đặt làm mặc định bằng đường viền màu xanh.
        border: addr.isDefault ? Border.all(color: Colors.blueAccent, width: 2) : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4)
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(addr.recipientName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15 + px),
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              /// Hiển thị nhãn "Mặc định" nếu địa chỉ được chọn làm ưu tiên.
              if (addr.isDefault) _buildDefaultBadge(),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.blue),
                onPressed: () => _openForm(context, address: addr),
              ),
              /// Chỉ cho phép xóa nếu địa chỉ đó không phải là địa chỉ mặc định.
              if (!addr.isDefault)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                  onPressed: () => _confirmDelete(context, addr.id),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(addr.phone, style: TextStyle(color: Colors.grey, fontSize: 13 + px)),
          const SizedBox(height: 8),
          Text("${addr.detail}, ${addr.ward}, ${addr.district}, ${addr.province}",
              style: TextStyle(fontSize: 13 + px, color: isDark ? Colors.white70 : Colors.black87)),
        ],
      ),
    );
  }

  /// Chức năng: Tạo nhãn hiển thị chữ "Mặc định".
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Widget Container được định dạng màu sắc.
  Widget _buildDefaultBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4)
    ),
    child: const Text("Mặc định",
        style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  /// Chức năng: Mở bảng nhập liệu (BottomSheet) để thêm mới hoặc chỉnh sửa địa chỉ.
  /// Tham số đầu vào: [context], [address] (Dữ liệu địa chỉ nếu muốn chỉnh sửa, để null nếu thêm mới).
  /// Giá trị trả về: Không có (Mở BottomSheet).
  void _openForm(BuildContext context, {AddressModel? address}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddressFormSheet(address: address),
    );
  }

  /// Chức năng: Hiển thị hộp thoại yêu cầu xác nhận trước khi thực hiện xóa địa chỉ.
  /// Tham số đầu vào: [context], [id] (ID của địa chỉ cần xóa).
  /// Giá trị trả về: Không có (Mở AlertDialog).
  void _confirmDelete(BuildContext context, int id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Xác nhận xóa?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text("Địa chỉ này sẽ bị gỡ khỏi sổ địa chỉ của bạn."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ĐÓNG")),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, elevation: 0),
              onPressed: () async {
                /// Logic xử lý xóa địa chỉ thông qua Provider.
                final base = context.read<BaseProvider>();
                await context.read<AddressProvider>().removeAddress(base.token!, id);
                /// Kiểm tra mounted để đảm bảo ứng dụng không crash nếu người dùng đã thoát dialog.
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text("XÓA", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }
}