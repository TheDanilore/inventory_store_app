class CategoryEntity {
  final String? id;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final int? productsCount;

  const CategoryEntity({
    this.id,
    required this.name,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.productsCount,
  });

  CategoryEntity copyWith({
    String? id,
    String? name,
    String? description,
    bool? isActive,
    DateTime? createdAt,
    int? productsCount,
  }) {
    return CategoryEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      productsCount: productsCount ?? this.productsCount,
    );
  }
}
