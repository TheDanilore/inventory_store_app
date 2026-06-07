class CategoryModel {
  final String? id;
  final String name;
  final String? description;
  final bool isActive;

  const CategoryModel({
    this.id,
    required this.name,
    this.description,
    this.isActive = true,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Sin nombre',
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
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
