class SystemSettingModel {
  final int id;
  final String keyName;
  final String value;
  final String? description;

  SystemSettingModel({
    required this.id,
    required this.keyName,
    required this.value,
    this.description,
  });

  factory SystemSettingModel.fromJson(Map<String, dynamic> json) {
    return SystemSettingModel(
      id: json['id'] ?? 0,
      keyName: json['key_name'] ?? '',
      value: json['value'] ?? '',
      description: json['description'],
    );
  }
}