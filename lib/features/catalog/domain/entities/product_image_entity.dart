class ProductImageEntity {
  final String id;
  final String productId;
  final String? variantId;
  final String imageUrl;
  final int displayOrder;
  final DateTime? createdAt;
  final bool isMain;

  const ProductImageEntity({
    required this.id,
    required this.productId,
    this.variantId,
    required this.imageUrl,
    this.displayOrder = 0,
    this.createdAt,
    this.isMain = false,
  });

  ProductImageEntity copyWith({
    String? id,
    String? productId,
    String? variantId,
    String? imageUrl,
    int? displayOrder,
    DateTime? createdAt,
    bool? isMain,
  }) {
    return ProductImageEntity(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      imageUrl: imageUrl ?? this.imageUrl,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      isMain: isMain ?? this.isMain,
    );
  }
}
