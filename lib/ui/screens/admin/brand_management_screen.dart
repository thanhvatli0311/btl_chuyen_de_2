import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

import '../../../data/models/category_brand_model.dart';
import '../../../data/repositories/api_service.dart';
import '../../../providers/base_provider.dart';

class BrandManagementScreen extends StatefulWidget {
  const BrandManagementScreen({super.key});

  @override
  State<BrandManagementScreen> createState() => _BrandManagementScreenState();
}

class _BrandManagementScreenState extends State<BrandManagementScreen> {

  List<BrandModel> _brands = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    /// Khởi tạo và nạp dữ liệu danh sách hãng ngay khi màn hình vừa được tạo.
    _loadBrands();
  }

  /// Chức năng: Gọi API để tải danh sách toàn bộ các hãng sản xuất điện thoại.
  /// Tham số đầu vào: Không có.
  /// Giá trị trả về: Future<void>.
  Future<void> _loadBrands() async {
    /// Lấy instance của ApiService từ BaseProvider để thực hiện request.
    final api = context.read<BaseProvider>().apiService;
    final list = await api.getBrands();

    /// Kiểm tra xem Widget còn tồn tại trong cây thư mục hay không trước khi cập nhật giao diện.
    if (mounted) {
      setState(() {
        _brands = list;
        _isLoading = false;
      });
    }
  }

  /// Chức năng: Hiển thị hộp thoại để người dùng nhập thông tin thêm mới hoặc cập nhật hãng.
  /// Tham số đầu vào: [brand] - Đối tượng Model hãng (nếu truyền vào sẽ là chế độ chỉnh sửa).
  /// Giá trị trả về: Không có.
  void _showBrandDialog({BrandModel? brand}) {
    final controller = TextEditingController(text: brand?.name ?? "");

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        /// Đồng bộ màu nền của hộp thoại theo cấu hình giao diện Sáng/Tối.
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(brand == null ? "Thêm Hãng Mới" : "Sửa Tên Hãng",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Tên hãng...", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("HỦY", style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            onPressed: () async {
              final base = context.read<BaseProvider>();
              final token = base.token;
              if (token == null) return;

              /// Dựa vào việc có đối tượng brand hay không để quyết định gọi API thêm mới hay cập nhật.
              final res = brand == null
                  ? await base.apiService.storeBrand(controller.text.trim(), token)
                  : await base.apiService.updateBrand(brand.id, controller.text.trim(), token);

              /// Xử lý phản hồi từ server và nạp lại danh sách hãng nếu thành công.
              if (res.data['success'] == true) {
                Fluttertoast.showToast(msg: res.data['message']);
                if (ctx.mounted) Navigator.pop(ctx);
                _loadBrands();
              }
            },
            child: const Text("XÁC NHẬN", style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    /// Lắng nghe trạng thái giao diện (Dark Mode) từ BaseProvider.
    final isDark = context.watch<BaseProvider>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text("QUẢN LÝ HÃNG", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBrandDialog(),
        backgroundColor: const Color(0xFF0047AB),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadBrands,
        child: ListView.builder(
          /// Cấu hình vùng đệm để tối ưu hóa hiệu năng cuộn trên các thiết bị Android.
          cacheExtent: 500,
          padding: const EdgeInsets.all(12),
          itemCount: _brands.length,
          itemBuilder: (context, index) {
            final b = _brands[index];
            return Card(
              color: Theme.of(context).cardColor,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: Text(b.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Slug: ${b.slug}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    /// Nút kích hoạt chức năng chỉnh sửa hãng.
                    IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () => _showBrandDialog(brand: b)
                    ),
                    /// Nút kích hoạt chức năng xóa hãng sau khi xác nhận.
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _confirmDelete(b),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Chức năng: Hiển thị hộp thoại cảnh báo để người dùng xác nhận hành động xóa.
  /// Tham số đầu vào: [b] - Đối tượng Model hãng cần xóa.
  /// Giá trị trả về: Không có.
  void _confirmDelete(BrandModel b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận xóa?"),
        content: Text("Bạn có chắc muốn xóa hãng '${b.name}' không?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ĐÓNG")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final base = context.read<BaseProvider>();

              /// Thực hiện gọi API xóa hãng từ máy chủ.
              final res = await base.apiService.deleteBrand(b.id, base.token!);

              /// Nếu xóa thành công trên DB, đóng hộp thoại và tải lại danh sách.
              if (res.data['success'] == true) {
                if (ctx.mounted) Navigator.pop(ctx);
                _loadBrands();
              }
            },
            child: const Text("XÓA", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}