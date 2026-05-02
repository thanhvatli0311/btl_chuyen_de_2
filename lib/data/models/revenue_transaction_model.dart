// 📂 file: lib/data/models/revenue_transaction_model.dart

class RevenueTransactionModel {
  final int id;
  final String type; // sale_revenue, withdraw, fee_collection...
  final double amount;
  final double balanceAfter;
  final String? referenceId; // Mã đơn hàng hoặc mã rút tiền
  final DateTime createdAt;

  RevenueTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.referenceId,
    required this.createdAt,
  });

  factory RevenueTransactionModel.fromJson(Map<String, dynamic> json) {
    return RevenueTransactionModel(
      id: json['id'] ?? 0,
      type: json['type'] ?? '',
      // Ép kiểu an toàn từ dynamic sang double
      amount: double.tryParse(json['amount'].toString()) ?? 0.0,
      balanceAfter: double.tryParse(json['balance_after'].toString()) ?? 0.0,
      referenceId: json['reference_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  // Helper để dịch loại giao dịch sang tiếng Việt trên giao diện
  String get typeLabel {
    switch (type) {
      case 'sale_revenue': return "Doanh thu đơn hàng";
      case 'withdraw': return "Rút tiền";
      case 'fee_collection': return "Phí vận hành sàn";
      default: return "Khác";
    }
  }
}