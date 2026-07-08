class ProductActiveIngredientEntity {
  final String productId;
  final String ingredientId;
  final double? concentration;
  final String? unit;

  const ProductActiveIngredientEntity({
    required this.productId,
    required this.ingredientId,
    this.concentration,
    this.unit,
  });

  ProductActiveIngredientEntity copyWith({
    String? productId,
    String? ingredientId,
    double? concentration,
    String? unit,
  }) {
    return ProductActiveIngredientEntity(
      productId: productId ?? this.productId,
      ingredientId: ingredientId ?? this.ingredientId,
      concentration: concentration ?? this.concentration,
      unit: unit ?? this.unit,
    );
  }
}
