import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
// Note: We'll temporarily use dynamic or generic if the inventory module is not yet migrated, 
// or import the entity if it exists. 
// For now, let's assume we map WarehouseStockBatch to its entity counterpart once Inventory is migrated.
// We'll use dynamic or the old model temporarily if needed, but best is to create a dummy entity or keep it out of core domain for now if it crosses modules.
// Let's import the model for now to not break the build, but ideally it should be an entity.
import 'package:inventory_store_app/features/inventory/data/models/warehouse_stock_batch_model.dart';

class ProductEntity {
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

  const ProductEntity({
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

  ProductEntity copyWith({
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
    List<ProductImageEntity>? images,
    int? totalStock,
    String? categoryName,
    List<ProductVariantEntity>? productVariants,
    List<WarehouseStockBatchModel>? warehouseStockBatches,
  }) {
    return ProductEntity(
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
      categoryName: categoryName ?? this.categoryName,
      productVariants: productVariants ?? this.productVariants,
      warehouseStockBatches: warehouseStockBatches ?? this.warehouseStockBatches,
    );
  }
}
