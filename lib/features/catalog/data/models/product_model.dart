import 'dart:convert';

import 'package:inventory_store_app/features/catalog/data/models/product_image_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_stock_batch_model.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';

class ProductModel {
  final String id;
  final String name;
  final bool isActive;
  final DateTime? createdAt;
  final String? categoryId;
  final String? description;
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

  // ── Helpers de precio (derivados de las variantes) ──────────────────────
  // "products" ya no tiene columnas de precio en la BD (unit_cost,
  // sale_price, wholesale_price, wholesale_min_quantity se movieron a
  // "product_variants"). Estos getters son solo de conveniencia para UI.

  /// Variante "por defecto" a mostrar cuando no hay una selección explícita.
  ProductVariantModel? get defaultVariant =>
      productVariants.isNotEmpty ? productVariants.first : null;

  /// Precio de venta a mostrar por defecto. Puede ser null si el producto
  /// no tiene ninguna variante todavía.
  double? get displaySalePrice => defaultVariant?.salePrice;

  /// Precio de venta más bajo entre todas las variantes activas, útil para
  /// mostrar "Desde $X" cuando hay varias variantes con precios distintos.
  double? get minSalePrice {
    final prices =
        productVariants
            .where((v) => v.isActive && v.salePrice != null)
            .map((v) => v.salePrice!)
            .toList();
    if (prices.isEmpty) return null;
    prices.sort();
    return prices.first;
  }

  ProductModel({
    required this.id,
    required this.name,
    this.isActive = true,
    this.createdAt,
    this.categoryId,
    this.description,
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
    final Map<String, dynamic> rawDetails = Map<String, dynamic>.from(
      json['details'] is String
          ? (jsonDecode(json['details'] as String) as Map<String, dynamic>)
          : (json['details'] as Map<String, dynamic>?) ?? {},
    );

    final paiList = json['product_active_ingredients'] as List?;
    if (paiList != null && paiList.isNotEmpty) {
      final names = <String>[];
      for (final item in paiList) {
        if (item is Map<String, dynamic>) {
          final ai = item['active_ingredients'] as Map<String, dynamic>?;
          if (ai != null && ai['name'] != null) {
            names.add(ai['name'].toString());
          }
        }
      }
      if (names.isNotEmpty) {
        rawDetails['active_ingredient'] = names.join(', ');
      }
    }

    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null,
      categoryId: json['category_id'] as String?,
      // ¡Aquí obtenemos el nombre real desde la consulta de la base de datos!
      categoryName: categoriesMap?['name'] as String? ?? 'Sin categoría',
      description: json['description'] as String?,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : null,
      details: rawDetails,
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
  /// Nota: totalStock NO se persiste en la BD (es calculado), y las variantes
  /// se persisten aparte (tabla product_variants), no dentro de este mapa.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'category_id': categoryId,
      'description': description,
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
    bool? isActive,
    DateTime? createdAt,
    String? categoryId,
    String? description,
    DateTime? updatedAt,
    Map<String, dynamic>? details,
    String? createdBy,
    String? updatedBy,
    bool? stockControl,
    bool? usesBatches,
    String? productType,
    List<ProductImageModel>? images,
    int? totalStock,
    String? categoryName,
    List<ProductVariantModel>? productVariants,
    List<WarehouseStockBatchModel>? warehouseStockBatches,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      updatedAt: updatedAt ?? this.updatedAt,
      details: details ?? this.details,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      stockControl: stockControl ?? this.stockControl,
      usesBatches: usesBatches ?? this.usesBatches,
      productType: productType ?? this.productType,
      images: images ?? this.images,
      totalStock: totalStock ?? this.totalStock,
      categoryName: categoryName ?? this.categoryName,
      productVariants: productVariants ?? this.productVariants,
      warehouseStockBatches:
          warehouseStockBatches ?? this.warehouseStockBatches,
    );
  }

  ProductEntity toEntity() {
    return ProductEntity(
      id: id,
      name: name,
      isActive: isActive,
      createdAt: createdAt,
      categoryId: categoryId,
      description: description,
      updatedAt: updatedAt,
      details: details,
      createdBy: createdBy,
      updatedBy: updatedBy,
      stockControl: stockControl,
      usesBatches: usesBatches,
      productType: productType,
      images: images.map((img) => img.toEntity()).toList(),
      totalStock: totalStock,
      categoryName: categoryName,
      productVariants: productVariants.map((v) => v.toEntity()).toList(),
      warehouseStockBatches: warehouseStockBatches,
    );
  }

  factory ProductModel.fromEntity(ProductEntity entity) {
    return ProductModel(
      id: entity.id,
      name: entity.name,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      categoryId: entity.categoryId,
      description: entity.description,
      updatedAt: entity.updatedAt,
      details: entity.details,
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
      stockControl: entity.stockControl,
      usesBatches: entity.usesBatches,
      productType: entity.productType,
      images:
          entity.images
              .map((img) => ProductImageModel.fromEntity(img))
              .toList(),
      totalStock: entity.totalStock,
      categoryName: entity.categoryName,
      productVariants:
          entity.productVariants
              .map((v) => ProductVariantModel.fromEntity(v))
              .toList(),
      warehouseStockBatches: entity.warehouseStockBatches,
    );
  }
}
