import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';

class VariantDraftEntity {
  final String? id;
  final String? sku;
  final String? barcode;
  final List<Map<String, dynamic>> selectedAttributes;
  final String? price;
  final String? wholesalePrice;
  final String? wholesaleMinQuantity;
  final String? reorderPoint;
  final String? unitCost;
  final List<String> urlsExistentes;
  final bool isActive;

  VariantDraftEntity({
    this.id,
    this.sku,
    this.barcode,
    this.selectedAttributes = const [],
    this.price,
    this.wholesalePrice,
    this.wholesaleMinQuantity,
    this.reorderPoint,
    this.unitCost,
    this.urlsExistentes = const [],
    this.isActive = true,
  });

  factory VariantDraftEntity.fromVariant(ProductVariantEntity variant) {
    final List<Map<String, dynamic>> currentAttributes = [];

    for (final av in variant.attributeValues) {
      currentAttributes.add({
        'attribute_id': av.attributeId,
        'attribute_name': av.attributeName,
        'value_id': av.attributeValueId,
        'value_name': av.value,
      });
    }

    return VariantDraftEntity(
      id: variant.id,
      sku: variant.sku,
      barcode: variant.barcode,
      selectedAttributes: currentAttributes,
      price: variant.salePrice?.toString(),
      wholesalePrice: variant.wholesalePrice?.toString(),
      wholesaleMinQuantity: variant.wholesaleMinQuantity?.toString(),
      reorderPoint: variant.reorderPoint.toString(),
      unitCost: variant.unitCost?.toString(),
      urlsExistentes: variant.images.isNotEmpty ? [variant.images.first.imageUrl] : [],
      isActive: variant.isActive,
    );
  }
}
