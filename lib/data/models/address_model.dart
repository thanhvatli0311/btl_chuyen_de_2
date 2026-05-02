class AddressModel {
  final int id;
  final String recipientName;
  final String phone;
  final String province;
  final String district;
  final String ward;
  final String detail;
  final bool isDefault;

  AddressModel({
    required this.id, required this.recipientName, required this.phone,
    required this.province, required this.district, required this.ward,
    required this.detail, required this.isDefault,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'] ?? 0,
      recipientName: json['recipient_name'] ?? '',
      phone: json['phone'] ?? '',
      province: json['province'] ?? '',
      district: json['district'] ?? '',
      ward: json['ward'] ?? '',
      detail: json['detail'] ?? '',
      isDefault: json['is_default'] == 1 || json['is_default'] == true,
    );
  }
}