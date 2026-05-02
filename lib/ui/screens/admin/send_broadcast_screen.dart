import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../../providers/base_provider.dart';
import '../../../providers/admin_provider.dart';

/// Chức năng: Màn hình dành cho Admin soạn và phát tin nhắn toàn hệ thống.
class SendBroadcastScreen extends StatefulWidget {
  const SendBroadcastScreen({super.key});
  @override
  State<SendBroadcastScreen> createState() => _SendBroadcastScreenState();
}

class _SendBroadcastScreenState extends State<SendBroadcastScreen> {
  final _msgCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  /// Trạng thái theo dõi quá trình xử lý của Server.
  bool _isSending = false;

  @override
  void dispose() {
    _msgCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<BaseProvider>().isDarkMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text("PHÁT THÔNG BÁO", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          /// Card lưu ý: Nhắc nhở Admin về phạm vi ảnh hưởng của tin nhắn.
          Card(
            elevation: 0,
            color: const Color(0xFF0047AB).withOpacity(0.05),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF0047AB)),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      "Lưu ý: Tin nhắn này sẽ xuất hiện trong hộp thư của tất cả người dùng trên hệ thống TSP Market.",
                      style: TextStyle(fontSize: 13, color: Colors.blueGrey, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          /// Card soạn thảo: Nơi nhập tiêu đề và nội dung.
          Card(
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.1),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Tiêu đề bản tin", style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: _titleCtrl,
                    decoration: const InputDecoration(
                      hintText: "Ví dụ: Ưu đãi tháng 5...",
                      border: UnderlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text("Nội dung chi tiết", style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    controller: _msgCtrl,
                    maxLines: 6,
                    decoration: InputDecoration(
                      hintText: "Nhập nội dung thông báo tại đây...",
                      filled: true,
                      fillColor: isDark ? Colors.white10 : Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),

          /// Nút gửi tin: Tự động chuyển sang trạng thái Loading khi đang xử lý.
          SizedBox(
            height: 55,
            child: ElevatedButton.icon(
              onPressed: _isSending ? null : _sendBroadcast,
              icon: _isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.campaign_rounded),
              label: Text(_isSending ? "ĐANG PHÁT TIN..." : "PHÁT TIN TOÀN SÀN"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0047AB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Chức năng: Gửi yêu cầu phát tin lên Server.
  void _sendBroadcast() async {
    if (_titleCtrl.text.trim().isEmpty || _msgCtrl.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: "Vui lòng nhập đầy đủ tiêu đề và nội dung");
      return;
    }

    setState(() => _isSending = true);
    final token = context.read<BaseProvider>().token;

    try {
      /// CHỈNH SỬA: Truyền tham số có tên (token, title, message) để khớp với logic mới.
      final success = await context.read<AdminProvider>().sendBroadcast(
        token: token!,
        title: _titleCtrl.text.trim(),
        message: _msgCtrl.text.trim(),
      );

      if (success && mounted) {
        Fluttertoast.showToast(msg: "🚀 Đã phát tin thành công!");
        Navigator.pop(context);
      } else {
        Fluttertoast.showToast(msg: "Gửi tin thất bại!");
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "Có lỗi xảy ra: $e");
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}