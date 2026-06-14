import 'dart:convert';
import 'package:inventory_store_app/models/product_image_model.dart';
import 'package:inventory_store_app/models/variant_attribute_value.dart';

class ProductVariantModel {
  final String id;
  final String productId;
  final String? sku;
  final String? barcode;

  /// [attributes] — columna JSONB legacy (se eliminará de la BD).
  /// Mantenida temporalmente para retrocompatibilidad mientras se migra.
  /// @deprecated — usar [attributeValues] en su lugar.
  final Map<String, dynamic> attributes;

  /// [attributeValues] — lista estructurada desde las nuevas tablas
  /// `attributes` + `attribute_values` + `variant_attribute_values`.
  /// Vacía si el join no fue incluido en la query.
  final List<VariantAttributeValue> attributeValues;

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
    this.attributes = const {},
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
  /// Prioridad: attributeValues (nuevas tablas) → attributes (legacy JSONB) →
  /// SKU → fallback genérico.
  String get label {
    // 1. Nuevas tablas estructuradas
    if (attributeValues.isNotEmpty) {
      return attributeValues.map((av) => av.value).join(' / ');
    }
    // 2. JSONB legacy (mientras no se migre)
    if (attributes.isNotEmpty) {
      return attributes.values.map((v) => v.toString()).join(' / ');
    }
    // 3. SKU como fallback
    if (sku != null && sku!.trim().isNotEmpty) return sku!;
    return 'Variante estándar';
  }

  /// Mapa key→value de los atributos para mostrar en UI (ej: {"Color":"Rojo"})
  Map<String, String> get attributeMap {
    if (attributeValues.isNotEmpty) {
      return {for (final av in attributeValues) av.attributeName: av.value};
    }
    return attributes.map((k, v) => MapEntry(k, v.toString()));
  }

  // ── fromJson ────────────────────────────────────────────────────────────────
  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    // Parsear attributeValues desde el join (si viene)
    List<VariantAttributeValue> parsedAttributeValues = [];
    final rawVav = json['variant_attribute_values'] as List<dynamic>?;
    if (rawVav != null && rawVav.isNotEmpty) {
      parsedAttributeValues =
          rawVav
              .map(
                (e) => VariantAttributeValue.fromJson(
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
      // Legacy JSONB — seguirá funcionando hasta que se elimine la columna
      attributes: _parseAttributes(json['attributes']),
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

  static Map<String, dynamic> _parseAttributes(dynamic raw) {
    if (raw == null) return {};
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        return decoded is Map ? Map<String, dynamic>.from(decoded) : {};
      } catch (_) {
        return {};
      }
    }
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
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
    'attributes': attributes, // legacy, se eliminará cuando se migre la BD
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
  };

  // ── copyWith ────────────────────────────────────────────────────────────────
  ProductVariantModel copyWith({
    String? id,
    String? productId,
    String? sku,
    String? barcode,
    Map<String, dynamic>? attributes,
    List<VariantAttributeValue>? attributeValues,
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
    attributes: attributes ?? this.attributes,
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
