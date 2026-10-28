import 'dart:collection';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';

/// Caché LRU en memoria para búsquedas, variantes y lotes del módulo de entradas.
///
/// Implementa política Zero-Shimmer y Stale-While-Revalidate (SWR):
/// - Capacidad fija [_maxEntries] por tipo de dato.
/// - TTL de 5 minutos para invalidar automáticamente datos viejos.
/// - Desalojo LRU (Least Recently Used) sobre LinkedHashMap.
class EntryProductCache {
  EntryProductCache._();

  static final EntryProductCache instance = EntryProductCache._();

  static const int _maxEntries = 50;
  static const Duration _ttl = Duration(minutes: 5);

  final LinkedHashMap<String, _CacheEntry<List<ProductModel>>> _searchCache =
      LinkedHashMap();
  final LinkedHashMap<String, _CacheEntry<List<ProductVariantModel>>>
  _variantCache = LinkedHashMap();
  final LinkedHashMap<String, _CacheEntry<List<Map<String, dynamic>>>>
  _batchCache = LinkedHashMap();

  // ── Búsqueda de Productos ──────────────────────────────────────────────────

  String _searchKey(String term) => 's:${term.toLowerCase().trim()}';

  List<ProductModel>? getSearchResults(String term) {
    return _get(_searchCache, _searchKey(term));
  }

  void putSearchResults(String term, List<ProductModel> results) {
    _put(_searchCache, _searchKey(term), List.unmodifiable(results));
  }

  // ── Variantes Activas ──────────────────────────────────────────────────────

  String _variantKey(String productId) => 'v:$productId';

  List<ProductVariantModel>? getVariants(String productId) {
    return _get(_variantCache, _variantKey(productId));
  }

  void putVariants(String productId, List<ProductVariantModel> variants) {
    _put(_variantCache, _variantKey(productId), List.unmodifiable(variants));
  }

  // ── Lotes por Variante y Almacén ───────────────────────────────────────────

  String _batchKey(String variantId, String warehouseId) =>
      'b:$variantId:$warehouseId';

  List<Map<String, dynamic>>? getBatches(String variantId, String warehouseId) {
    return _get(_batchCache, _batchKey(variantId, warehouseId));
  }

  void putBatches(
    String variantId,
    String warehouseId,
    List<Map<String, dynamic>> batches,
  ) {
    _put(
      _batchCache,
      _batchKey(variantId, warehouseId),
      List.unmodifiable(
        batches.map((b) => Map<String, dynamic>.from(b)).toList(),
      ),
    );
  }

  // ── Invocaciones de limpieza / invalidación ────────────────────────────────

  void invalidateVariant(String productId) {
    _variantCache.remove(_variantKey(productId));
  }

  void invalidateBatch(String variantId, String warehouseId) {
    _batchCache.remove(_batchKey(variantId, warehouseId));
  }

  void clear() {
    _searchCache.clear();
    _variantCache.clear();
    _batchCache.clear();
  }

  // ── Helpers genéricos LRU ─────────────────────────────────────────────────

  T? _get<T>(LinkedHashMap<String, _CacheEntry<T>> map, String key) {
    final entry = map[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.cachedAt) > _ttl) {
      map.remove(key);
      return null;
    }
    // Promover en orden LRU (re-insertar al final)
    map
      ..remove(key)
      ..[key] = entry;
    return entry.data;
  }

  void _put<T>(LinkedHashMap<String, _CacheEntry<T>> map, String key, T data) {
    map.remove(key);
    if (map.length >= _maxEntries) {
      map.remove(map.keys.first);
    }
    map[key] = _CacheEntry(data, DateTime.now());
  }
}

class _CacheEntry<T> {
  final T data;
  final DateTime cachedAt;

  const _CacheEntry(this.data, this.cachedAt);
}
