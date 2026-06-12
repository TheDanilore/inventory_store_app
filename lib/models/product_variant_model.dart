import 'dart:convert';

import 'package:inventory_store_app/models/product_image_model.dart';

class ProductVariantModel {
  final String id;
  final String productId;
  final String? sku;
  final Map<String, dynamic> attributes;
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

  ProductVariantModel({
    required this.id,
    required this.productId,
    this.sku,
    this.attributes = const {},
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

  /// Etiqueta legible para mostrar en la UI.
  /// Ej: attributes = {"color":"Rojo","talla":"M"} → "Rojo / M"
  /// Fallback: SKU, o "Variante id" si no hay nada más.
  String get label {
    if (attributes.isNotEmpty) {
      return attributes.values.map((v) => v.toString()).join(' / ');
    }
    if (sku != null && sku!.isNotEmpty) return sku!;
    return 'Variante $id';
  }

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    return ProductVariantModel(
      id: json['id'] as String,
      // product_id puede no venir en joins parciales (ej: cart_items select)
      productId: json['product_id'] as String? ?? '',
      sku: json['sku'] as String?,
      attributes:
          json['attributes'] is String
              ? jsonDecode(json['attributes'] as String) as Map<String, dynamic>
              : (json['attributes'] as Map<String, dynamic>?) ?? {},
      unitCost:
          json['unit_cost'] != null
              ? (json['unit_cost'] as num).toDouble()
              : null,
      salePrice:
          json['sale_price'] != null
              ? (json['sale_price'] as num).toDouble()
              : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null,
      reorderPoint: json['reorder_point'] as int? ?? 3,
      wholesalePrice:
          json['wholesale_price'] != null
              ? (json['wholesale_price'] as num).toDouble()
              : null,
      wholesaleMinQuantity: json['wholesale_min_quantity'] as int?,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      images:
          json['product_images'] != null
              ? (json['product_images'] as List)
                  .map(
                    (img) =>
                        ProductImageModel.fromJson(img as Map<String, dynamic>),
                  )
                  .toList()
              : const [],
    );
  }

  get primaryImageUrl => images.isNotEmpty ? images.first.imageUrl : null;

  /// Método para convertir el modelo a un mapa para insertar/actualizar en SQL.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'sku': sku,
      'attributes': attributes,
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
  }

  ProductVariantModel copyWith({
    String? id,
    String? productId,
    String? sku,
    Map<String, dynamic>? attributes,
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
  }) {
    return ProductVariantModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      sku: sku ?? this.sku,
      attributes: attributes ?? this.attributes,
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
