import 'dart:collection';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_product_by_id_uc.dart';

/// Elemento interno almacenado en la caché con marca de tiempo.
class _CachedProductEntry {
  final ProductEntity product;
  final DateTime cachedAt;

  const _CachedProductEntry({required this.product, required this.cachedAt});

  bool isExpired(Duration ttl) {
    return DateTime.now().difference(cachedAt) > ttl;
  }
}

/// Servicio singleton de caché en memoria (LRU) para fichas de producto rápidas.
///
/// Permite aperturas instantáneas en Frame 0 (Zero-Shimmer) eliminando
/// llamadas redundantes a Supabase y minimizando estrictamente el Data Egress.
class QuickViewProductCache {
  QuickViewProductCache._();
  static final QuickViewProductCache instance = QuickViewProductCache._();

  static const int _maxEntries = 60;
  static const Duration defaultTtl = Duration(minutes: 5);

  final LinkedHashMap<String, _CachedProductEntry> _cache =
      LinkedHashMap<String, _CachedProductEntry>();

  /// Obtiene el producto en memoria si existe y es válido.
  ProductEntity? get(String productId, {Duration ttl = defaultTtl}) {
    final entry = _cache[productId];
    if (entry == null) return null;

    if (entry.isExpired(ttl)) {
      _cache.remove(productId);
      return null;
    }

    // Mueve al final para política LRU (más recientemente usado)
    _cache.remove(productId);
    _cache[productId] = entry;
    return entry.product;
  }

  /// Verifica si el producto ya está en caché y vigente sin alterar el orden LRU.
  bool has(String productId, {Duration ttl = defaultTtl}) {
    final entry = _cache[productId];
    if (entry == null) return false;
    if (entry.isExpired(ttl)) {
      _cache.remove(productId);
      return false;
    }
    return true;
  }

  /// Guarda o actualiza un producto en la caché LRU.
  void put(String productId, ProductEntity product) {
    if (_cache.containsKey(productId)) {
      _cache.remove(productId);
    } else if (_cache.length >= _maxEntries) {
      _cache.remove(_cache.keys.first); // Expulsa el más antiguo
    }

    _cache[productId] = _CachedProductEntry(
      product: product,
      cachedAt: DateTime.now(),
    );
  }

  /// Carga el producto desde Supabase si no está en caché o si se fuerza refresco.
  Future<ProductEntity?> loadProduct(
    String productId, {
    bool forceRefresh = false,
    Duration ttl = defaultTtl,
  }) async {
    if (!forceRefresh) {
      final cached = get(productId, ttl: ttl);
      if (cached != null) return cached;
    }

    try {
      final getProductUc = sl<GetProductByIdUC>();
      final Either<Failure, ProductEntity?> result = await getProductUc(
        productId,
        forceRefresh: forceRefresh,
      );
      final ProductEntity? product = result.fold((failure) => null, (p) => p);
      if (product != null) {
        put(productId, product);
      }
      return product;
    } catch (_) {
      return null;
    }
  }

  /// Invalida un producto específico de la caché.
  void invalidate(String productId) {
    _cache.remove(productId);
  }

  /// Limpia toda la caché de sesión.
  void clear() {
    _cache.clear();
  }
}
