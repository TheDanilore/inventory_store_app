import 'package:equatable/equatable.dart';

class OrderItemEntity extends Equatable {
  final String id;
  final String orderId;
  final String? productId;
  final String? variantId;
  final int quantity;
  final double unitCost;
  final double appliedPrice;
  final double netProfit;
  final DateTime? createdAt;

  final String? productName;
  final String? sku;
  final Map<String, dynamic> attributes;
  final String? variantImageUrl;
  final String? productImageUrl;

  const OrderItemEntity({
    required this.id,
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

  // La lógica vive ÚNICAMENTE aquí
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
    // Bug corregido
    return attributes.entries
        .map((entry) => '${entry.key}: ${entry.value}')
        .join(' | ');
  }

  String? get variantDisplayName =>
      variantLabel.isNotEmpty ? variantLabel : null;

  OrderItemEntity copyWith({
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
    return OrderItemEntity(
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

  @override
  List<Object?> get props => [
    id,
    orderId,
    productId,
    variantId,
    quantity,
    unitCost,
    appliedPrice,
    netProfit,
    createdAt,
    productName,
    sku,
    attributes,
    variantImageUrl,
    productImageUrl,
  ];
}
