import 'dart:convert';

import 'package:inventory_store_app/features/catalog/data/models/product_image_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_stock_batch_model.dart';

class ProductModel {
  final String id;
  final String name;
  final double unitCost;
  final double salePrice;
  final bool isActive;
  final DateTime? createdAt;
  final String? categoryId;
  final String? description;
  final double? wholesalePrice;
  final int wholesaleMinQuantity;
  final DateTime? updatedAt;
  final Map<String, dynamic> details;
  final String? createdBy;
  final String? updatedBy;
  final bool stockControl;
  final bool usesBatches;
  final String productType; // 'good', 'service', 'digital'

  final List<ProductImageModel> images;

  /// Campo calculado en tiempo de ejecución: suma de available_quantity
  /// de warehouse_stock_batches para este producto. No viene de la BD
  /// directamente; se inyecta desde la pantalla/servicio.
  final int totalStock;

  /// URL de la imagen principal del producto (is_main=true, o la primera).
  String? get primaryImageUrl {
    if (images.isEmpty) return null;
    try {
      return images.firstWhere((img) => img.isMain).imageUrl;
    } catch (_) {
      return images.first.imageUrl;
    }
  }

  final String? categoryName;
  final List<ProductVariantModel> productVariants;
  final List<WarehouseStockBatchModel> warehouseStockBatches;

  ProductModel({
    required this.id,
    required this.name,
    required this.unitCost,
    required this.salePrice,
    this.isActive = true,
    this.createdAt,
    this.categoryId,
    this.description,
    this.wholesalePrice,
    this.wholesaleMinQuantity = 3,
    this.updatedAt,
    this.details = const {},
    this.createdBy,
    this.updatedBy,
    this.stockControl = true,
    this.usesBatches = false,
    this.productType = 'good',
    this.images = const [],
    this.totalStock = 0,
    this.categoryName,
    this.productVariants = const [],
    this.warehouseStockBatches = const [],
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    final categoriesMap = json['categories'] as Map<String, dynamic>?;
    final variantsList = json['product_variants'] as List? ?? [];
    final batchesList = json['warehouse_stock_batches'] as List? ?? [];
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      unitCost: (json['unit_cost'] as num).toDouble(),
      salePrice: (json['sale_price'] as num).toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null,
      categoryId: json['category_id'] as String?,
      // ¡Aquí obtenemos el nombre real desde la consulta de la base de datos!
      categoryName: categoriesMap?['name'] as String? ?? 'Sin categoría',
      description: json['description'] as String?,
      wholesalePrice:
          json['wholesale_price'] != null
              ? (json['wholesale_price'] as num).toDouble()
              : null,
      wholesaleMinQuantity: json['wholesale_min_quantity'] as int? ?? 3,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : null,
      details:
          json['details'] is String
              ? jsonDecode(json['details'] as String) as Map<String, dynamic>
              : (json['details'] as Map<String, dynamic>?) ?? {},
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      stockControl: json['stock_control'] as bool? ?? true,
      usesBatches: json['uses_batches'] as bool? ?? false,
      productType: json['product_type'] as String? ?? 'good',
      productVariants:
          variantsList
              .map(
                (variantJson) => ProductVariantModel.fromJson(
                  variantJson as Map<String, dynamic>,
                ),
              )
              .toList(),
      warehouseStockBatches:
          batchesList
              .map(
                (bJson) => WarehouseStockBatchModel.fromJson(
                  bJson as Map<String, dynamic>,
                ),
              )
              .toList(),

      images:
          json['product_images'] != null
              ? (json['product_images'] as List)
                  .map(
                    (img) =>
                        ProductImageModel.fromJson(img as Map<String, dynamic>),
                  )
                  .toList()
              : const [],
      // totalStock no viene del JSON de Supabase; se inyecta externamente.
      totalStock:
          json['total_stock'] != null
              ? (json['total_stock'] as num).toInt()
              : 0,
    );
  }

  /// Método para convertir el modelo de Dart a un mapa para insertar/actualizar en SQL.
  /// Nota: totalStock NO se persiste en la BD (es calculado).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unit_cost': unitCost,
      'sale_price': salePrice,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'category_id': categoryId,
      'description': description,
      'wholesale_price': wholesalePrice,
      'wholesale_min_quantity': wholesaleMinQuantity,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'details': details,
      'created_by': createdBy,
      'updated_by': updatedBy,
      'stock_control': stockControl,
      'uses_batches': usesBatches,
      'product_type': productType,
      'product_images': images.map((img) => img.toJson()).toList(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    double? unitCost,
    double? salePrice,
    bool? isActive,
    DateTime? createdAt,
    String? categoryId,
    String? description,
    double? wholesalePrice,
    int? wholesaleMinQuantity,
    DateTime? updatedAt,
    Map<String, dynamic>? details,
    String? createdBy,
    String? updatedBy,
    bool? stockControl,
    bool? usesBatches,
    String? productType,
    List<ProductImageModel>? images,
    int? totalStock,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      unitCost: unitCost ?? this.unitCost,
      salePrice: salePrice ?? this.salePrice,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      wholesaleMinQuantity: wholesaleMinQuantity ?? this.wholesaleMinQuantity,
      updatedAt: updatedAt ?? this.updatedAt,
      details: details ?? this.details,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      stockControl: stockControl ?? this.stockControl,
      usesBatches: usesBatches ?? this.usesBatches,
      productType: productType ?? this.productType,
      images: images ?? this.images,
      totalStock: totalStock ?? this.totalStock,
    );
  }
}
