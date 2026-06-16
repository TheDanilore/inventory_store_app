class CategoryModel {
  final String? id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final int? productsCount;

  const CategoryModel({
    this.id,
    required this.name,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.productsCount,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Sin nombre',
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
      productsCount: _parseProductsCount(json['products']),
    );
  }

  static int? _parseProductsCount(dynamic productsData) {
    if (productsData == null) return null;
    if (productsData is List) {
      if (productsData.isNotEmpty && productsData.first is Map) {
        return productsData.first['count'] as int?;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'description': description,
      'is_active': isActive,
    };
  }
}
