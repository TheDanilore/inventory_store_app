class InventoryBatchItem {
  final String id;
  final String batchNumber;
  final String? expiryDate;
  final int availableQuantity;
  final String warehouseId;
  final String? warehouseName;
  final String? supplierId;
  final String? supplierName;
  final String variantId;
  final String productId;
  final String? productName;
  final String? variantAttrs;
  final String? sku;
  final bool usesBatches;
  final String? imageUrl;
  
  // Computados
  String status;
  int? daysRemaining;

  InventoryBatchItem({
    required this.id,
    required this.batchNumber,
    this.expiryDate,
    required this.availableQuantity,
    required this.warehouseId,
    this.warehouseName,
    this.supplierId,
    this.supplierName,
    required this.variantId,
    required this.productId,
    this.productName,
    this.variantAttrs,
    this.sku,
    required this.usesBatches,
    this.imageUrl,
    this.status = 'sin_vencimiento',
    this.daysRemaining,
  }) {
    _computeExpiryStatus();
  }

  void _computeExpiryStatus() {
    if (expiryDate == null) {
      status = 'sin_vencimiento';
      daysRemaining = null;
      return;
    }
    final expiry = DateTime.tryParse(expiryDate!);
    if (expiry == null) {
      status = 'sin_vencimiento';
      return;
    }
    final diff = expiry.difference(DateTime.now()).inDays;
    daysRemaining = diff;
    if (diff < 0) {
      status = 'vencido';
    } else if (diff <= 30) {
      status = 'critico';
    } else if (diff <= 90) {
      status = 'proximo';
    } else {
      status = 'normal';
    }
  }
}

class InventoryStockItem {
  final String productId;
  final String productName;
  final String category;
  final String productType;
  final bool usesBatches;
  final bool stockControl;
  final double unitCost;
  final double salePrice;
  final double? wholesalePrice;
  final int wholesaleMinQty;
  final String variantId;
  final String? sku;
  final String attrsText;
  final String? imageUrl;
  final int reorderPoint;
  final int stock;
  final List<InventoryBatchItem> batches;
  final bool isLowStock;

  const InventoryStockItem({
    required this.productId,
    required this.productName,
    required this.category,
    required this.productType,
    required this.usesBatches,
    required this.stockControl,
    required this.unitCost,
    required this.salePrice,
    this.wholesalePrice,
    required this.wholesaleMinQty,
    required this.variantId,
    this.sku,
    required this.attrsText,
    this.imageUrl,
    required this.reorderPoint,
    required this.stock,
    required this.batches,
    required this.isLowStock,
  });

  double get profit => salePrice - unitCost;
  double get margin => unitCost > 0 ? (profit / salePrice) * 100 : 0;
}
