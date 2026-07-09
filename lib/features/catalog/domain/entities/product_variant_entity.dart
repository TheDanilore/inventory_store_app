import 'package:inventory_store_app/features/catalog/domain/entities/variant_attribute_value_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';

class ProductVariantEntity {
  String get label {
    if (sku != null && sku!.isNotEmpty) {
      return sku!;
    }
    if (attributeValues.isNotEmpty) {
      return attributeValues.map((av) => av.value).join(' / ');
    }
    return 'Variante ';
  }

  Map<String, String> get attributeMap {
    final map = <String, String>{};
    for (final av in attributeValues) {
      map[av.attributeName] = av.value;
    }
    return map;
  }

  final String id;
  final String productId;
  final String? sku;
  final String? barcode;
  final List<VariantAttributeValueEntity> attributeValues;
  final double? unitCost;
  final double? salePrice;
  final bool isActive;
  final DateTime? createdAt;
  final int reorderPoint;
  final double? wholesalePrice;
  final int? wholesaleMinQuantity;
  final String? createdBy;
  final String? updatedBy;
  final List<ProductImageEntity> images;

  const ProductVariantEntity({
    required this.id,
    required this.productId,
    this.sku,
    this.barcode,
    this.attributeValues = const [],
    this.unitCost,
    this.salePrice,
    this.isActive = true,
    this.createdAt,
    this.reorderPoint = 0,
    this.wholesalePrice,
    this.wholesaleMinQuantity,
    this.createdBy,
    this.updatedBy,
    this.images = const [],
  });

  ProductVariantEntity copyWith({
    String? id,
    String? productId,
    String? sku,
    String? barcode,
    List<VariantAttributeValueEntity>? attributeValues,
    double? unitCost,
    double? salePrice,
    bool? isActive,
    DateTime? createdAt,
    int? reorderPoint,
    double? wholesalePrice,
    int? wholesaleMinQuantity,
    String? createdBy,
    String? updatedBy,
    List<ProductImageEntity>? images,
  }) {
    return ProductVariantEntity(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      attributeValues: attributeValues ?? this.attributeValues,
      unitCost: unitCost ?? this.unitCost,
      salePrice: salePrice ?? this.salePrice,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      reorderPoint: reorderPoint ?? this.reorderPoint,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      wholesaleMinQuantity: wholesaleMinQuantity ?? this.wholesaleMinQuantity,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      images: images ?? this.images,
    );
  }
}
