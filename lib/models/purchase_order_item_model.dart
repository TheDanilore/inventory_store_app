class PurchaseOrderItemModel {
  final String productId;
  final String variantId;
  final String? productName;
  final String variantAttrs;
  final String? sku;
  final double quantityOrdered;
  final double quantityReceived;
  final double unitCost;
  final String batchNumber;
  final DateTime? expiryDate;
  final bool usesBatches;

  /// URL de imagen: primero busca la de la variante, si no la del producto
  final String? imageUrl;

  const PurchaseOrderItemModel({
    required this.productId,
    required this.variantId,
    this.productName,
    required this.variantAttrs,
    this.sku,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.unitCost,
    required this.batchNumber,
    this.expiryDate,
    required this.usesBatches,
    this.imageUrl,
  });

  double get subtotal => quantityOrdered * unitCost;
  bool get fullyReceived => quantityReceived >= quantityOrdered;
}
