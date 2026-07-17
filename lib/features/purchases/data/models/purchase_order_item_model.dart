import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_item_entity.dart';

class PurchaseOrderItemModel extends PurchaseOrderItemEntity {

  const PurchaseOrderItemModel({
    required super.productId,
    required super.variantId,
    super.productName,
    required super.variantAttrs,
    super.sku,
    required super.quantityOrdered,
    required super.quantityReceived,
    required super.unitCost,
    required super.batchNumber,
    super.expiryDate,
    required super.usesBatches,
    super.imageUrl,
  });
}
