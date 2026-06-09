import 'package:inventory_store_app/models/product_model.dart';

class CartItemModel {
  final ProductModel product;
  int quantity;
  final String cartKey;
  final String? variantId;
  final String? variantLabel;
  final double unitPrice;
  final double? wholesalePrice;
  final String? imageUrl;
  final String? sku;
  int availableStock;

  // Indica si el producto gestiona stock por lotes (uses_batches en products).
  // Se propaga desde ProductModel al añadir al carrito, NO viene de la BD
  // de cart_items — es un dato de producto, no del carrito.
  final bool usesBatches;

  bool isSelected;

  CartItemModel({
    required this.product,
    this.quantity = 1,
    this.variantId,
    this.variantLabel,
    double? unitPrice,
    this.wholesalePrice,
    this.imageUrl,
    this.sku,
    int? availableStock,
    bool? usesBatches,
    String? cartKey,
    this.isSelected = true,
  }) : unitPrice = unitPrice ?? product.salePrice,
       // Si no se pasa explícitamente, lo tomamos del propio ProductModel.
       // Así nunca queda en false por descuido al construir el ítem.
       usesBatches = usesBatches ?? product.usesBatches,
       availableStock = availableStock ?? 0,
       cartKey = cartKey ?? buildKey(product.id, variantId);

  static String buildKey(String productId, String? variantId) {
    return variantId == null || variantId.isEmpty
        ? productId
        : '$productId:$variantId';
  }

  double get totalItemPrice => unitPrice * quantity;

  // ── Serialización (para persistencia local, p.ej. Hive/SharedPreferences) ─

  Map<String, dynamic> toJson() {
    return {
      'product': product.toJson(),
      'quantity': quantity,
      'variantId': variantId,
      'variantLabel': variantLabel,
      'unitPrice': unitPrice,
      'wholesalePrice': wholesalePrice,
      'imageUrl': imageUrl,
      'sku': sku,
      'availableStock': availableStock,
      'cartKey': cartKey,
      'usesBatches': usesBatches,
      'isSelected': isSelected,
    };
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    final product = ProductModel.fromJson(
      json['product'] as Map<String, dynamic>,
    );
    return CartItemModel(
      product: product,
      quantity: (json['quantity'] as num).toInt(),
      variantId: json['variantId'] as String?,
      variantLabel: json['variantLabel'] as String?,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      wholesalePrice:
          json['wholesalePrice'] != null
              ? (json['wholesalePrice'] as num).toDouble()
              : null,
      imageUrl: json['imageUrl'] as String?,
      sku: json['sku'] as String?,
      availableStock: (json['availableStock'] as num).toInt(),
      cartKey: json['cartKey'] as String,
      // Si viene de un JSON antiguo sin este campo, el fallback es product.usesBatches.
      usesBatches: json['usesBatches'] as bool? ?? product.usesBatches,
      isSelected: json['isSelected'] as bool? ?? true,
    );
  }

  CartItemModel copyWith({
    ProductModel? product,
    int? quantity,
    String? cartKey,
    String? variantId,
    String? variantLabel,
    double? unitPrice,
    double? wholesalePrice,
    String? imageUrl,
    String? sku,
    int? availableStock,
    bool? usesBatches,
    bool? isSelected,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      cartKey: cartKey ?? this.cartKey,
      variantId: variantId ?? this.variantId,
      variantLabel: variantLabel ?? this.variantLabel,
      unitPrice: unitPrice ?? this.unitPrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      imageUrl: imageUrl ?? this.imageUrl,
      sku: sku ?? this.sku,
      availableStock: availableStock ?? this.availableStock,
      usesBatches: usesBatches ?? this.usesBatches,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
