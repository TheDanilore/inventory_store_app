/// Entidad de un ítem en el carrito del POS.
///
/// Objeto de negocio inmutable. No depende de Supabase ni de JSON.
/// Contiene la lógica de negocio relacionada con el ítem (subtotal,
/// validaciones, etc.).
class CartItemEntity {
  final String productId;
  final String productName;
  final String cartKey;
  final String? variantId;
  final String? variantLabel;
  final int quantity;
  final double unitPrice;
  final double? wholesalePrice;
  final double unitCost;
  final String? imageUrl;
  final String? sku;
  final int availableStock;
  final bool usesBatches;
  final bool isSelected;

  const CartItemEntity({
    required this.productId,
    required this.productName,
    required this.cartKey,
    required this.quantity,
    required this.unitPrice,
    required this.unitCost,
    required this.availableStock,
    required this.usesBatches,
    this.variantId,
    this.variantLabel,
    this.wholesalePrice,
    this.imageUrl,
    this.sku,
    this.isSelected = true,
  });

  // ── Lógica de negocio pura ─────────────────────────────────────────────────

  /// Subtotal de este ítem (precio × cantidad).
  double get subtotal => unitPrice * quantity;

  /// Ganancia bruta de este ítem ((precio - costo) × cantidad).
  double get grossProfit => (unitPrice - unitCost) * quantity;

  /// Margen de ganancia como porcentaje (0-100).
  double get marginPercent =>
      unitCost > 0 ? ((unitPrice - unitCost) / unitCost) * 100 : 0;

  /// Indica si hay stock suficiente para la cantidad seleccionada.
  bool get hasEnoughStock => availableStock >= quantity;

  /// Clave estática para construir el [cartKey] de forma consistente.
  static String buildKey(String productId, String? variantId) {
    return (variantId == null || variantId.isEmpty)
        ? productId
        : '$productId:$variantId';
  }

  CartItemEntity copyWith({
    String? productId,
    String? productName,
    String? cartKey,
    String? variantId,
    String? variantLabel,
    int? quantity,
    double? unitPrice,
    double? wholesalePrice,
    double? unitCost,
    String? imageUrl,
    String? sku,
    int? availableStock,
    bool? usesBatches,
    bool? isSelected,
  }) {
    return CartItemEntity(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      cartKey: cartKey ?? this.cartKey,
      variantId: variantId ?? this.variantId,
      variantLabel: variantLabel ?? this.variantLabel,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      unitCost: unitCost ?? this.unitCost,
      imageUrl: imageUrl ?? this.imageUrl,
      sku: sku ?? this.sku,
      availableStock: availableStock ?? this.availableStock,
      usesBatches: usesBatches ?? this.usesBatches,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CartItemEntity && other.cartKey == cartKey);

  @override
  int get hashCode => cartKey.hashCode;

  @override
  String toString() =>
      'CartItemEntity(key: $cartKey, qty: $quantity, price: $unitPrice)';
}
