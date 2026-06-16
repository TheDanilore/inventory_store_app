import 'package:inventory_store_app/models/product_image_model.dart';
import 'package:inventory_store_app/models/variant_attribute_value_model.dart';

class ProductVariantModel {
  final String id;
  final String productId;
  final String? sku;
  final String? barcode;

  /// Lista estructurada desde las nuevas tablas
  /// `attributes` + `attribute_values` + `variant_attribute_values`.
  final List<VariantAttributeValueModel> attributeValues;

  final double? unitCost;
  final double? salePrice;
  final bool isActive;
  final DateTime? createdAt;
  final int reorderPoint;
  final double? wholesalePrice;
  final int? wholesaleMinQuantity;
  final String? createdBy;
  final String? updatedBy;
  final List<ProductImageModel> images;

  const ProductVariantModel({
    required this.id,
    required this.productId,
    this.sku,
    this.barcode,
    this.attributeValues = const [],
    this.unitCost,
    this.salePrice,
    this.isActive = true,
    this.createdAt,
    this.reorderPoint = 3,
    this.wholesalePrice,
    this.wholesaleMinQuantity,
    this.createdBy,
    this.updatedBy,
    this.images = const [],
  });

  // ── Label legible ───────────────────────────────────────────────────────────
  String get label {
    if (attributeValues.isNotEmpty) {
      return attributeValues
          .map(
            (av) =>
                av.attributeName.isNotEmpty
                    ? '${av.attributeName}: ${av.value}'
                    : av.value,
          )
          .join(' / ');
    }
    if (sku != null && sku!.trim().isNotEmpty) return sku!;
    return 'Variante estándar';
  }

  /// Mapa key→value de los atributos para mostrar en UI (ej: {"Color":"Rojo"})
  Map<String, String> get attributeMap {
    if (attributeValues.isNotEmpty) {
      return {for (final av in attributeValues) av.attributeName: av.value};
    }
    return {};
  }

  // ── fromJson ────────────────────────────────────────────────────────────────
  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    List<VariantAttributeValueModel> parsedAttributeValues = [];
    final rawVav = json['variant_attribute_values'] as List<dynamic>?;
    if (rawVav != null && rawVav.isNotEmpty) {
      parsedAttributeValues =
          rawVav
              .map(
                (e) => VariantAttributeValueModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList();
    }

    return ProductVariantModel(
      id: json['id'] as String,
      productId: json['product_id'] as String? ?? '',
      sku: json['sku'] as String?,
      barcode: json['barcode'] as String?,
      attributeValues: parsedAttributeValues,
      unitCost: (json['unit_cost'] as num?)?.toDouble(),
      salePrice: (json['sale_price'] as num?)?.toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'] as String)
              : null,
      reorderPoint: json['reorder_point'] as int? ?? 3,
      wholesalePrice: (json['wholesale_price'] as num?)?.toDouble(),
      wholesaleMinQuantity: json['wholesale_min_quantity'] as int?,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      images: _parseImages(json['product_images']),
    );
  }

  static List<ProductImageModel> _parseImages(dynamic raw) {
    if (raw == null) return const [];
    if (raw is! List) return const [];
    try {
      return raw
          .map((e) => ProductImageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  // ── toJson ──────────────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id': id,
    'product_id': productId,
    'sku': sku,
    'barcode': barcode,
    'unit_cost': unitCost,
    'sale_price': salePrice,
    'is_active': isActive,
    if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    'reorder_point': reorderPoint,
    'wholesale_price': wholesalePrice,
    'wholesale_min_quantity': wholesaleMinQuantity,
    'created_by': createdBy,
    'updated_by': updatedBy,
    'product_images': images.map((img) => img.toJson()).toList(),
    'variant_attribute_values': attributeValues.map((av) => av.toJson()).toList(),
  };

  // ── copyWith ────────────────────────────────────────────────────────────────
  ProductVariantModel copyWith({
    String? id,
    String? productId,
    String? sku,
    String? barcode,
    List<VariantAttributeValueModel>? attributeValues,
    double? unitCost,
    double? salePrice,
    bool? isActive,
    DateTime? createdAt,
    int? reorderPoint,
    double? wholesalePrice,
    int? wholesaleMinQuantity,
    String? createdBy,
    String? updatedBy,
    List<ProductImageModel>? images,
  }) => ProductVariantModel(
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

  String? get primaryImageUrl =>
      images.isNotEmpty ? images.first.imageUrl : null;
}
