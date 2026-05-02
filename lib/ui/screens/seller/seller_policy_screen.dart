import 'package:flutter/material.dart';

class SellerPolicyScreen extends StatelessWidget {
  const SellerPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text("CHÍNH SÁCH NGƯỜI BÁN",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildIntroCard(isDark),
            const SizedBox(height: 20),
            _buildPolicySection(
              "💰 Quy định Tài chính",
              [
                "Mức phí sàn: 5% trên mỗi đơn hàng thành công.",
                "Tiền cọc vận hành: 1.000.000đ (Duy trì để đảm bảo trách nhiệm bảo hành).",
                "Thời gian đối soát: Tiền sẽ về ví sau khi đơn hàng chuyển trạng thái 'Thành công' (Delivered).",
              ],
              Icons.payments_outlined,
              Colors.blue,
              isDark,
            ),
            _buildPolicySection(
              "📱 Quy định Đăng tin",
              [
                "Hình ảnh: Phải là ảnh thật của sản phẩm, tối thiểu 3 ảnh (Trước, Sau, Cạnh bên).",
                "Mô tả: Ghi rõ tình trạng Pin, ngoại hình và các linh kiện đã thay thế (nếu có).",
                "Phân loại: Phải chọn đúng dòng máy, dung lượng và màu sắc.",
                "Nghiêm cấm: Đăng bán hàng giả, hàng nhái (Fake), máy dính iCloud/MDM không rõ nguồn gốc.",
              ],
              Icons.vibration,
              Colors.orange,
              isDark,
            ),
            _buildPolicySection(
              "📦 Quy trình Vận hành",
              [
                "Xác nhận đơn: Người bán có 24h để xác nhận đơn hàng mới.",
                "Đóng gói: Sử dụng chống sốc chuyên dụng cho điện thoại để tránh hư hỏng.",
                "Giao hàng: Đơn vị vận chuyển sẽ đến lấy hàng sau khi bạn xác nhận 'Sẵn sàng giao'.",
                "Trạng thái: Chỉ những đơn 'Đã giao' mới được tính vào doanh thu thực nhận.",
              ],
              Icons.local_shipping_outlined,
              Colors.teal,
              isDark,
            ),
            _buildPolicySection(
              "🛡️ Xử lý Vi phạm",
              [
                "Khóa tài khoản vĩnh viễn nếu phát hiện hành vi gian lận.",

              ],
              Icons.gavel_outlined,
              Colors.redAccent,
              isDark,
            ),
            const SizedBox(height: 20),
            _buildFooterText(),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0047AB), Color(0xFF002147)]),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.white70, size: 40),
          SizedBox(width: 15),
          Expanded(
            child: Text(
              "Chào mừng bạn gia nhập hệ thống Phone Market. Vui lòng đọc kỹ các quy định để đảm bảo việc kinh doanh hiệu quả.",
              style: TextStyle(color: Colors.white, fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPolicySection(String title, List<String> rules, IconData icon, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 15),
          ...rules.map((rule) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("• ", style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    rule,
                    style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildFooterText() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Text(
        "Cập nhật lần cuối: Tháng 04/2026\nBan quản trị Phone Market",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
      ),
    );
  }
}