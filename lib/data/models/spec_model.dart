class SpecModel {
  final int id;
  final int phoneId;
  final String specKey;
  final String specValue;

  SpecModel({
    required this.id,
    required this.phoneId,
    required this.specKey,
    required this.specValue,
  });

  factory SpecModel.fromJson(Map<String, dynamic> json) {
    return SpecModel(
      id: json['id'] ?? 0,
      phoneId: json['phone_id'] ?? 0,
      specKey: json['spec_key'] ?? '',
      specValue: json['spec_value'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone_id': phoneId,
    'spec_key': specKey,
    'spec_value': specValue,
  };
}