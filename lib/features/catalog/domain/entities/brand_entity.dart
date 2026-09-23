class BrandEntity {
  final String? id;
  final String name;
  final String? description;
  final String? logoUrl;
  final String? website;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? productsCount;

  const BrandEntity({
    this.id,
    required this.name,
    this.description,
    this.logoUrl,
    this.website,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.productsCount,
  });

  BrandEntity copyWith({
    String? id,
    String? name,
    String? description,
    String? logoUrl,
    String? website,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? productsCount,
  }) {
    return BrandEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      website: website ?? this.website,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      productsCount: productsCount ?? this.productsCount,
    );
  }
}
