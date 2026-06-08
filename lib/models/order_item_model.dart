import 'package:inventory_store_app/models/product_image_model.dart';

class OrderItemModel {
  final String? id;
  final String orderId;
  final String? productId;
  final String? variantId;
  int quantity;
  final double unitCost;
  final double appliedPrice;
  final double netProfit;
  final DateTime? createdAt;
  final String? productName;
  final String? sku;
  final Map<String, dynamic> attributes;
  final String? variantImageUrl;
  final String? productImageUrl;

  OrderItemModel({
    this.id,
    required this.orderId,
    this.productId,
    this.variantId,
    required this.quantity,
    required this.unitCost,
    required this.appliedPrice,
    required this.netProfit,
    this.createdAt,
    this.productName,
    this.sku,
    this.attributes = const {},
    this.variantImageUrl,
    this.productImageUrl,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    final product = json['products'] as Map<String, dynamic>?;
    final variant = json['product_variants'] as Map<String, dynamic>?;
    final productImages = product?['product_images'] as List<dynamic>? ?? [];
    final variantImages = variant?['product_images'] as List<dynamic>? ?? [];
    String? variantImageUrl;
    String? productImageUrl;

    if (variantImages.isNotEmpty) {
      try {
        final images =
            variantImages
                .map(
                  (e) =>
                      ProductImageModel.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList();
        if (images.isNotEmpty) {
          variantImageUrl =
              images
                  .firstWhere(
                    (image) => image.isMain,
                    orElse: () => images.first,
                  )
                  .imageUrl;
        }
      } catch (_) {
        variantImageUrl = null;
      }
    }

    if (productImages.isNotEmpty) {
      try {
        final images =
            productImages
                .map(
                  (e) =>
                      ProductImageModel.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList();
        if (images.isNotEmpty) {
          productImageUrl =
              images
                  .firstWhere(
                    (image) => image.isMain,
                    orElse: () => images.first,
                  )
                  .imageUrl;
        }
      } catch (_) {
        productImageUrl = null;
      }
    }

    return OrderItemModel(
      id: json['id'] as String?,
      orderId: json['order_id'] as String? ?? '',
      productId: json['product_id'] as String?,
      variantId: json['variant_id'] as String?,
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitCost: (json['unit_cost'] as num?)?.toDouble() ?? 0,
      appliedPrice: (json['applied_price'] as num?)?.toDouble() ?? 0,
      netProfit: (json['net_profit'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      productName: product?['name'] as String?,
      sku: variant?['sku'] as String?,
      attributes: Map<String, dynamic>.from(
        variant?['attributes'] as Map? ?? {},
      ),
      variantImageUrl: variantImageUrl,
      productImageUrl: productImageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'order_id': orderId,
      'product_id': productId,
      'variant_id': variantId,
      'quantity': quantity,
      'unit_cost': unitCost,
      'applied_price': appliedPrice,
      'net_profit': netProfit,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  double get subtotal => appliedPrice * quantity;

  String? get displayImageUrl =>
      (variantImageUrl != null && variantImageUrl!.isNotEmpty)
          ? variantImageUrl
          : (productImageUrl != null && productImageUrl!.isNotEmpty)
          ? productImageUrl
          : null;

  String get variantLabel {
    if (attributes.isEmpty) {
      return sku?.trim().isNotEmpty == true ? sku! : 'Variante estándar';
    }

    return attributes.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' | ');
  }

  get variantDisplayName => variantLabel.isNotEmpty ? variantLabel : null;
}
