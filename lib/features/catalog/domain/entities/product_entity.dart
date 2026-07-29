import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_stock_batch_model.dart';

class ProductEntity {
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
  final String productType;

  final List<ProductImageEntity> images;
  final int totalStock;
  final String? categoryName;
  final List<ProductVariantEntity> productVariants;
  final List<WarehouseStockBatchModel> warehouseStockBatches;

  String? get primaryImageUrl {
    if (images.isEmpty) return null;
    try {
      return images.firstWhere((img) => img.isMain).imageUrl;
    } catch (_) {
      return images.first.imageUrl;
    }
  }

  // ── Helpers de precio (derivados de las variantes) ──────────────────────
  // El producto ya NO tiene precio propio: unit_cost, sale_price,
  // wholesale_price y wholesale_min_quantity viven únicamente en
  // ProductVariantEntity. Estos getters son solo de conveniencia para
  // pantallas de listado/tarjeta que necesitan mostrar "un" precio
  // representativo sin tener que resolver la variante seleccionada.

  /// Variante "por defecto" a mostrar cuando no hay una selección explícita
  /// (ej. tarjeta de producto en el listado, antes de elegir variante).
  ProductVariantEntity? get defaultVariant =>
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

  const ProductEntity({
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

  ProductEntity copyWith({
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
    List<ProductImageEntity>? images,
    int? totalStock,
    String? categoryName,
    List<ProductVariantEntity>? productVariants,
    List<WarehouseStockBatchModel>? warehouseStockBatches,
  }) {
    return ProductEntity(
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
}
