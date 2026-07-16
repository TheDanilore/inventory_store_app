import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';

class OrderItemModel extends OrderItemEntity {
  const OrderItemModel({
    required super.id,
    required super.orderId,
    super.productId,
    super.variantId,
    required super.quantity,
    required super.unitCost,
    required super.appliedPrice,
    required super.netProfit,
    super.createdAt,
    super.productName,
    super.sku,
    super.attributes,
    super.variantImageUrl,
    super.productImageUrl,
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
        final mainImg = variantImages.firstWhere(
          (img) => img['is_main'] == true,
          orElse: () => variantImages.first,
        );
        variantImageUrl = mainImg['image_url'] as String?;
      } catch (_) {
        variantImageUrl = null;
      }
    }

    if (productImages.isNotEmpty) {
      try {
        final mainImg = productImages.firstWhere(
          (img) => img['is_main'] == true,
          orElse: () => productImages.first,
        );
        productImageUrl = mainImg['image_url'] as String?;
      } catch (_) {
        productImageUrl = null;
      }
    }

    // ── PARSEO DE LA NUEVA ESTRUCTURA RELACIONAL DE ATRIBUTOS ──
    Map<String, dynamic> parsedAttributes = {};
    if (variant != null && variant['variant_attribute_values'] != null) {
      final vavList =
          variant['variant_attribute_values'] as List<dynamic>? ?? [];
      for (final vav in vavList) {
        final attrValueMap = vav['attribute_values'] as Map<String, dynamic>?;
        if (attrValueMap != null) {
          final val = attrValueMap['value']?.toString() ?? '';
          final attrHeader =
              attrValueMap['attributes'] as Map<String, dynamic>?;
          final key = attrHeader?['name']?.toString() ?? 'Atributo';
          parsedAttributes[key] = val;
        }
      }
    } else if (variant != null && variant['attributes'] != null) {
      // Fallback temporal por si aún consultas la columna vieja antes de borrarla
      parsedAttributes = Map<String, dynamic>.from(
        variant['attributes'] as Map? ?? {},
      );
    }

    return OrderItemModel(
      id: json['id'] as String? ?? '',
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
      attributes: parsedAttributes,
      variantImageUrl: variantImageUrl,
      productImageUrl: productImageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
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

  @override
  double get subtotal => appliedPrice * quantity;

  @override
  String? get displayImageUrl =>
      (variantImageUrl != null && variantImageUrl!.isNotEmpty)
          ? variantImageUrl
          : (productImageUrl != null && productImageUrl!.isNotEmpty)
          ? productImageUrl
          : null;

  @override
  String get variantLabel {
    if (attributes.isEmpty) {
      return sku?.trim().isNotEmpty == true ? sku! : 'Variante estándar';
    }

    return attributes.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' | ');
  }

  String? get variantDisplayName =>
      variantLabel.isNotEmpty ? variantLabel : null;

  @override
  OrderItemModel copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? variantId,
    int? quantity,
    double? unitCost,
    double? appliedPrice,
    double? netProfit,
    DateTime? createdAt,
    String? productName,
    String? sku,
    Map<String, dynamic>? attributes,
    String? variantImageUrl,
    String? productImageUrl,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      appliedPrice: appliedPrice ?? this.appliedPrice,
      netProfit: netProfit ?? this.netProfit,
      createdAt: createdAt ?? this.createdAt,
      productName: productName ?? this.productName,
      sku: sku ?? this.sku,
      attributes: attributes ?? this.attributes,
      variantImageUrl: variantImageUrl ?? this.variantImageUrl,
      productImageUrl: productImageUrl ?? this.productImageUrl,
    );
  }
}
