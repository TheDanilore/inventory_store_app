import 'dart:collection';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';

/// Caché LRU en memoria para listas de productos (catálogo).
///
/// Singleton — sobrevive a la destrucción de Cubits y Widgets.
/// Permite renderizar datos en Frame 0 al regresar a una vista
/// sin shimmer visible (Zero-Shimmer / Stale-While-Revalidate).
///
/// Capacidades:
///   - Páginas de catálogo: hasta [maxPages] entradas, TTL [pageTtl].
///   - Detalles de producto: hasta [maxProducts] entradas, TTL [productTtl].
class CatalogLruCache {
  CatalogLruCache._();
  static final CatalogLruCache instance = CatalogLruCache._();

  // ── Configuración ─────────────────────────────────────────────────────────
  static const int maxPages = 40;
  static const int maxProducts = 80;
  static const Duration pageTtl = Duration(minutes: 5);
  static const Duration productTtl = Duration(minutes: 5);

  // ── Caché de páginas paginadas ─────────────────────────────────────────────
  final LinkedHashMap<String, _PageEntry> _pages = LinkedHashMap();

  // ── Caché de detalles de producto individual ───────────────────────────────
  final LinkedHashMap<String, _ProductEntry> _products = LinkedHashMap();

  // ── API de Páginas de Catálogo ─────────────────────────────────────────────

  /// Clave única que codifica todos los parámetros de la consulta.
  static String buildKey({
    String? searchQuery,
    String? categoryId,
    String? brandId,
    bool? isActive,
    bool searchByIngredient = false,
    bool forCustomer = false,
    int limit = 20,
    int offset = 0,
    CatalogSortOption? sortOption,
    CatalogStockFilter? stockFilter,
  }) {
    return [
      searchQuery?.trim().toLowerCase() ?? '',
      categoryId ?? '',
      brandId ?? '',
      isActive?.toString() ?? 'null',
      searchByIngredient.toString(),
      forCustomer.toString(),
      limit.toString(),
      offset.toString(),
      sortOption?.name ?? '',
      stockFilter?.name ?? '',
    ].join('|');
  }

  /// Retorna la página cacheada si existe y no está vencida. O(1).
  ({List<ProductEntity> products, int totalCount})? getPage(String key) {
    final entry = _pages[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.cachedAt) > pageTtl) {
      _pages.remove(key);
      return null;
    }
    // Política LRU: mover al final (más reciente).
    _pages
      ..remove(key)
      ..[key] = entry;
    return (products: entry.products, totalCount: entry.totalCount);
  }

  /// Almacena una página de catálogo. Evicta la entrada más antigua si se
  /// supera [maxPages]. Si la clave ya existía, se promueve al final.
  void putPage(String key, List<ProductEntity> products, int totalCount) {
    _pages.remove(key);
    if (_pages.length >= maxPages) {
      _pages.remove(_pages.keys.first);
    }
    _pages[key] = _PageEntry(
      products: List.unmodifiable(products),
      totalCount: totalCount,
      cachedAt: DateTime.now(),
    );
  }

  /// Invalida TODAS las páginas del catálogo (tras mutaciones).
  void invalidateCatalog() => _pages.clear();

  // ── API de Detalles de Producto Individual ─────────────────────────────────

  /// Retorna el producto cacheado si existe y no está vencido. O(1).
  ProductEntity? getProduct(String id) {
    final entry = _products[id];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.cachedAt) > productTtl) {
      _products.remove(id);
      return null;
    }
    _products
      ..remove(id)
      ..[id] = entry;
    return entry.product;
  }

  /// Almacena un producto individual. Evicta la entrada más antigua si se
  /// supera [maxProducts]. Si la clave ya existía, se promueve al final.
  void putProduct(String id, ProductEntity product) {
    _products.remove(id);
    if (_products.length >= maxProducts) {
      _products.remove(_products.keys.first);
    }
    _products[id] = _ProductEntry(product: product, cachedAt: DateTime.now());
  }

  /// Invalida un producto específico (tras edición o eliminación).
  void invalidateProduct(String id) => _products.remove(id);

  /// Limpia toda la caché (logout, cambio de tenant, etc.).
  void clear() {
    _pages.clear();
    _products.clear();
  }
}

// ── Entries internas ──────────────────────────────────────────────────────────

class _PageEntry {
  final List<ProductEntity> products;
  final int totalCount;
  final DateTime cachedAt;

  const _PageEntry({
    required this.products,
    required this.totalCount,
    required this.cachedAt,
  });
}

class _ProductEntry {
  final ProductEntity product;
  final DateTime cachedAt;

  const _ProductEntry({required this.product, required this.cachedAt});
}
