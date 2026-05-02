class DailyRevenueModel {
  final String date;
  final double totalGmv;
  final double commission;

  DailyRevenueModel({required this.date, required this.totalGmv, required this.commission});

  factory DailyRevenueModel.fromJson(Map<String, dynamic> json) {
    return DailyRevenueModel(
      date: json['date'] ?? '',
      totalGmv: double.tryParse(json['total_gmv']?.toString() ?? '0') ?? 0.0,
      commission: double.tryParse(json['commission']?.toString() ?? '0') ?? 0.0,
    );
  }
}