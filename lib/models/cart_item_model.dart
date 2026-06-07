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
  int availableStock; // Nota: Lo ideal es pasar este valor desde la consulta de stock real
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
    int? availableStock, // Cambiado a requerido o con valor por defecto seguro
    String? cartKey,
    this.isSelected = true,
  })  : unitPrice = unitPrice ?? product.salePrice,
        // CORRECCIÓN 1: Como product.currentStock no existe, por defecto iniciamos en 0 
        // a menos que inyectes el stock real de la variante/lote al añadir al carrito.
        availableStock = availableStock ?? 0, 
        // CORRECCIÓN 2: product.id es obligatorio, no necesitas usar ?? ''
        cartKey = cartKey ?? buildKey(product.id, variantId);

  static String buildKey(String productId, String? variantId) {
    return variantId == null || variantId.isEmpty
        ? productId
        : '$productId:$variantId';
  }

  double get totalItemPrice => unitPrice * quantity;

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
      'isSelected': isSelected,
    };
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      product: ProductModel.fromJson(json['product'] as Map<String, dynamic>),
      // CORRECCIÓN 3: Casteos numéricos explícitos y seguros para persistencia local
      quantity: (json['quantity'] as num).toInt(),
      variantId: json['variantId'] as String?,
      variantLabel: json['variantLabel'] as String?,
      unitPrice: (json['unitPrice'] as num).toDouble(),
      wholesalePrice: json['wholesalePrice'] != null 
          ? (json['wholesalePrice'] as num).toDouble() 
          : null,
      imageUrl: json['imageUrl'] as String?,
      sku: json['sku'] as String?,
      availableStock: (json['availableStock'] as num).toInt(),
      cartKey: json['cartKey'] as String,
      isSelected: json['isSelected'] as bool? ?? true,
    );
  }

  /// Método copyWith añadido para facilitar la actualización de cantidades 
  /// o selección en tus gestores de estado (Bloc, Riverpod, Provider).
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
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
