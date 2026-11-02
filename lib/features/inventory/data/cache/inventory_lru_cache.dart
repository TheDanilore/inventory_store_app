import 'dart:collection';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';

class InventoryStockPageCache {
  final List<InventoryStockItem> stockItems;
  final int totalCount;
  final int totalPages;
  final DateTime cachedAt;

  const InventoryStockPageCache({
    required this.stockItems,
    required this.totalCount,
    required this.totalPages,
    required this.cachedAt,
  });
}

class InventoryMetricsCache {
  final Map<String, dynamic> metrics;
  final DateTime cachedAt;

  const InventoryMetricsCache({required this.metrics, required this.cachedAt});
}

class InventoryLruCache {
  InventoryLruCache._();
  static final InventoryLruCache instance = InventoryLruCache._();

  static const int maxPages = 30;
  static const Duration pageTtl = Duration(minutes: 5);
  static const Duration metricsTtl = Duration(minutes: 5);

  final LinkedHashMap<String, InventoryStockPageCache> _stockPages =
      LinkedHashMap();
  final LinkedHashMap<String, InventoryMetricsCache> _metrics = LinkedHashMap();

  List<WarehouseEntity>? _warehouses;
  DateTime? _warehousesCachedAt;

  List<String>? _categories;
  DateTime? _categoriesCachedAt;

  static String buildStockKey({
    String search = '',
    String categoryName = 'Todos',
    String stockStatus = 'all',
    String? warehouseId,
    int page = 0,
    int pageSize = 24,
  }) {
    return [
      search.trim().toLowerCase(),
      categoryName.trim(),
      stockStatus.trim(),
      warehouseId ?? 'all',
      page.toString(),
      pageSize.toString(),
    ].join('|');
  }

  InventoryStockPageCache? getStockPage(String key) {
    final entry = _stockPages[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.cachedAt) > pageTtl) {
      _stockPages.remove(key);
      return null;
    }
    _stockPages
      ..remove(key)
      ..[key] = entry;
    return entry;
  }

  void putStockPage(
    String key, {
    required List<InventoryStockItem> stockItems,
    required int totalCount,
    required int totalPages,
  }) {
    _stockPages.remove(key);
    if (_stockPages.length >= maxPages) {
      _stockPages.remove(_stockPages.keys.first);
    }
    _stockPages[key] = InventoryStockPageCache(
      stockItems: List.unmodifiable(stockItems),
      totalCount: totalCount,
      totalPages: totalPages,
      cachedAt: DateTime.now(),
    );
  }

  Map<String, dynamic>? getMetrics(String? warehouseId) {
    final key = warehouseId ?? 'all';
    final entry = _metrics[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.cachedAt) > metricsTtl) {
      _metrics.remove(key);
      return null;
    }
    _metrics
      ..remove(key)
      ..[key] = entry;
    return entry.metrics;
  }

  void putMetrics(String? warehouseId, Map<String, dynamic> metrics) {
    final key = warehouseId ?? 'all';
    _metrics.remove(key);
    _metrics[key] = InventoryMetricsCache(
      metrics: Map.unmodifiable(metrics),
      cachedAt: DateTime.now(),
    );
  }

  List<WarehouseEntity>? getWarehouses() {
    if (_warehouses == null || _warehousesCachedAt == null) return null;
    if (DateTime.now().difference(_warehousesCachedAt!) > pageTtl) {
      _warehouses = null;
      return null;
    }
    return _warehouses;
  }

  void putWarehouses(List<WarehouseEntity> warehouses) {
    _warehouses = List.unmodifiable(warehouses);
    _warehousesCachedAt = DateTime.now();
  }

  List<String>? getCategories() {
    if (_categories == null || _categoriesCachedAt == null) return null;
    if (DateTime.now().difference(_categoriesCachedAt!) > pageTtl) {
      _categories = null;
      return null;
    }
    return _categories;
  }

  void putCategories(List<String> categories) {
    _categories = List.unmodifiable(categories);
    _categoriesCachedAt = DateTime.now();
  }

  bool get hasAnyStock => _stockPages.isNotEmpty;

  void invalidateStock() {
    _stockPages.clear();
    _metrics.clear();
  }

  void invalidateAll() {
    _stockPages.clear();
    _metrics.clear();
    _warehouses = null;
    _categories = null;
  }
}
