class ProductActiveIngredientModel {
  final String productId;
  final String ingredientId;
  final double? concentration;
  final String? unit;

  ProductActiveIngredientModel({
    required this.productId,
    required this.ingredientId,
    this.concentration,
    this.unit,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory ProductActiveIngredientModel.fromJson(Map<String, dynamic> json) {
    return ProductActiveIngredientModel(
      productId: json['product_id'] as String,
      ingredientId: json['ingredient_id'] as String,
      concentration:
          json['concentration'] != null
              ? (json['concentration'] as num).toDouble()
              : null,
      unit: json['unit'] as String?,
    );
  }

  /// Método para convertir el modelo de Dart a un mapa estructurado para insertar/actualizar en SQL
  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'ingredient_id': ingredientId,
      'concentration': concentration,
      'unit': unit,
    };
  }

  /// Método copyWith ideal para el manejo de estados (Bloc, Riverpod, etc.)
  ProductActiveIngredientModel copyWith({
    String? productId,
    String? ingredientId,
    double? concentration,
    String? unit,
  }) {
    return ProductActiveIngredientModel(
      productId: productId ?? this.productId,
      ingredientId: ingredientId ?? this.ingredientId,
      concentration: concentration ?? this.concentration,
      unit: unit ?? this.unit,
    );
  }
}
