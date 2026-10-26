import 'dart:collection';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';

/// Caché LRU en memoria para variantes y lotes del módulo de salidas.
///
/// Capacidad fija [maxEntries] entradas. Al superar el límite se expulsa la
/// entrada más antigua (LRU). Además cuenta con un TTL de 5 minutos para
/// evitar servir datos de stock desactualizados. Thread-safe en Dart isolate.
///
/// ### Claves
/// - **Variantes**: `"v:<productId>"`
/// - **Lotes**:     `"b:<variantId>:<warehouseId>"`
class ExitProductCache {
  ExitProductCache._();

  static final ExitProductCache instance = ExitProductCache._();

  static const int _maxEntries = 40;
  static const Duration _ttl = Duration(minutes: 5);

  final LinkedHashMap<String, _CacheEntry<List<ProductVariantModel>>>
  _variantCache = LinkedHashMap();
  final LinkedHashMap<String, _CacheEntry<List<Map<String, dynamic>>>>
  _batchCache = LinkedHashMap();

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

  // ── Utilidades ─────────────────────────────────────────────────────────────

  /// Invalida las variantes de un producto en caché.
  void invalidateVariants(String productId) {
    _variantCache.remove(_variantKey(productId));
  }

  /// Invalida los lotes de una variante en un almacén concreto.
  /// Útil tras confirmar una salida real.
  void invalidateBatches(String variantId, String warehouseId) {
    _batchCache.remove(_batchKey(variantId, warehouseId));
  }

  /// Limpia toda la caché (ej. al cerrar sesión o recargar almacén).
  void clear() {
    _variantCache.clear();
    _batchCache.clear();
  }
}

class _CacheEntry<T> {
  final T data;
  final DateTime cachedAt;

  const _CacheEntry(this.data, this.cachedAt);
}
