class CategoryModel {
  final int id;
  final String name;
  CategoryModel({required this.id, required this.name});
  factory CategoryModel.fromJson(Map<String, dynamic> json) =>
      CategoryModel(id: json['id'], name: json['name']);
}

class BrandModel {
  final int id;
  final String name;
  final String? slug;
  final String? logo;
  final String? description;

  BrandModel({
    required this.id,
    required this.name,
    this.slug,
    this.logo,
    this.description,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    return BrandModel(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      logo: json['logo'],
      description: json['description'],
    );
  }
}
