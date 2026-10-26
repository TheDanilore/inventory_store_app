import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_image_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/variant_financial_summary_entity.dart';

/// Modelo que encapsula los datos cacheados de un producto.
class CachedProductDetail {
  final ProductEntity? product;
  final List<Map<String, dynamic>> warehouseStocks;
  final List<Map<String, dynamic>> batchesList;
  final List<ProductImageEntity> images;
  final List<ProductVariantEntity> variants;
  final List<Map<String, dynamic>> reviewsList;
  final List<Map<String, dynamic>> activeIngredients;
  final double averageRating;
  final int totalSold;
  final double reinvestmentNeeded;
  final double totalRevenue;
  final double inventoryValue;
  final List<VariantFinancialSummaryEntity> variantSummaries;
  final DateTime cachedAt;

  CachedProductDetail({
    this.product,
    required this.warehouseStocks,
    required this.batchesList,
    required this.images,
    required this.variants,
    required this.reviewsList,
    required this.activeIngredients,
    required this.averageRating,
    required this.totalSold,
    required this.reinvestmentNeeded,
    required this.totalRevenue,
    required this.inventoryValue,
    required this.variantSummaries,
    DateTime? cachedAt,
  }) : cachedAt = cachedAt ?? DateTime.now();

  bool isExpired([Duration ttl = const Duration(minutes: 10)]) {
    return DateTime.now().difference(cachedAt) > ttl;
  }
}

/// Gestor de caché L1 en memoria para detalles de producto.
/// Evita recargas y shimmers innecesarios al navegar entre pantallas.
@lazySingleton
class ProductDetailCache {
  static final ProductDetailCache _instance = ProductDetailCache._internal();
  factory ProductDetailCache() => _instance;
  static ProductDetailCache get instance => _instance;

  ProductDetailCache._internal();

  final Map<String, CachedProductDetail> _cache = {};

  /// Recupera los datos cacheados si existen.
  CachedProductDetail? get(String productId) {
    return _cache[productId];
  }

  /// Almacena en memoria los datos del producto.
  void put(String productId, CachedProductDetail detail) {
    _cache[productId] = detail;
  }

  /// Invalida el caché de un producto específico (ej. tras editarlo).
  void invalidate(String productId) {
    _cache.remove(productId);
  }

  /// Limpia todo el caché en memoria.
  void clear() {
    _cache.clear();
  }
}
