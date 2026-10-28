import 'dart:collection';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';

/// Caché LRU en memoria para variantes, lotes y búsquedas del módulo de salidas.
///
/// Capacidad fija [maxEntries] entradas. Al superar el límite se expulsa la
/// entrada más antigua (LRU). Además cuenta con un TTL de 5 minutos para
/// evitar servir datos de stock desactualizados. Thread-safe en Dart isolate.
///
/// ### Claves
/// - **Variantes**: `"v:<productId>"`
/// - **Lotes**:     `"b:<variantId>:<warehouseId>"`
/// - **Búsquedas**: `"s:<normalizedQuery>"`
class ExitProductCache {
  ExitProductCache._();

  static final ExitProductCache instance = ExitProductCache._();

  static const int _maxEntries = 40;
  static const Duration _ttl = Duration(minutes: 5);

  final LinkedHashMap<String, _CacheEntry<List<ProductVariantModel>>>
  _variantCache = LinkedHashMap();
  final LinkedHashMap<String, _CacheEntry<List<Map<String, dynamic>>>>
  _batchCache = LinkedHashMap();
  final LinkedHashMap<String, _CacheEntry<List<ProductModel>>> _searchCache =
      LinkedHashMap();

  // ── Variantes ──────────────────────────────────────────────────────────────

  String _variantKey(String productId) => 'v:$productId';

  List<ProductVariantModel>? getVariants(String productId) {
    final key = _variantKey(productId);
    final entry = _variantCache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.cachedAt) > _ttl) {
      _variantCache.remove(key);
      return null;
    }
    // Promover a "más reciente" (refresh LRU order).
    _variantCache
      ..remove(key)
      ..[key] = entry;
    return entry.data;
  }

  void putVariants(String productId, List<ProductVariantModel> variants) {
    final key = _variantKey(productId);
    _variantCache.remove(key);
    if (_variantCache.length >= _maxEntries) {
      _variantCache.remove(_variantCache.keys.first);
    }
    _variantCache[key] = _CacheEntry(
      List.unmodifiable(variants),
      DateTime.now(),
    );
  }

  // ── Lotes ──────────────────────────────────────────────────────────────────

  String _batchKey(String variantId, String warehouseId) =>
      'b:$variantId:$warehouseId';

  List<Map<String, dynamic>>? getBatches(String variantId, String warehouseId) {
    final key = _batchKey(variantId, warehouseId);
    final entry = _batchCache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.cachedAt) > _ttl) {
      _batchCache.remove(key);
      return null;
    }
    _batchCache
      ..remove(key)
      ..[key] = entry;
    return entry.data;
  }

  void putBatches(
    String variantId,
    String warehouseId,
    List<Map<String, dynamic>> batches,
  ) {
    final key = _batchKey(variantId, warehouseId);
    _batchCache.remove(key);
    if (_batchCache.length >= _maxEntries) {
      _batchCache.remove(_batchCache.keys.first);
    }
    _batchCache[key] = _CacheEntry(
      List.unmodifiable(
        batches.map((b) => Map<String, dynamic>.from(b)).toList(),
      ),
      DateTime.now(),
    );
  }

  // ── Búsqueda de Productos ──────────────────────────────────────────────────

  String _searchKey(String query) => 's:${query.trim().toLowerCase()}';

  List<ProductModel>? getSearchResults(String query) {
    final key = _searchKey(query);
    final entry = _searchCache[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.cachedAt) > _ttl) {
      _searchCache.remove(key);
      return null;
    }
    _searchCache
      ..remove(key)
      ..[key] = entry;
    return entry.data;
  }

  void putSearchResults(String query, List<ProductModel> products) {
    final key = _searchKey(query);
    _searchCache.remove(key);
    if (_searchCache.length >= _maxEntries) {
      _searchCache.remove(_searchCache.keys.first);
    }
    _searchCache[key] = _CacheEntry(
      List.unmodifiable(products),
      DateTime.now(),
    );
  }

  // ── Utilidades ─────────────────────────────────────────────────────────────

  /// Invalida las variantes de un producto en caché.
  void invalidateVariants(String productId) {
    _variantCache.remove(_variantKey(productId));
  }

  /// Invalida los lotes de una variante en un almacén concreto.
  void invalidateBatches(String variantId, String warehouseId) {
    _batchCache.remove(_batchKey(variantId, warehouseId));
  }

  /// Invalida todos los lotes cacheados para un almacén específico
  /// (usado tras guardar una salida exitosa para garantizar consistencia ACID).
  void invalidateWarehouseBatches(String warehouseId) {
    final suffix = ':$warehouseId';
    _batchCache.removeWhere((key, _) => key.endsWith(suffix));
  }

  /// Limpia toda la caché (ej. al cerrar sesión o recargar almacén).
  void clear() {
    _variantCache.clear();
    _batchCache.clear();
    _searchCache.clear();
  }
}

class _CacheEntry<T> {
  final T data;
  final DateTime cachedAt;

  const _CacheEntry(this.data, this.cachedAt);
}
