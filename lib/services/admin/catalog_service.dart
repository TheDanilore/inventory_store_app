import 'dart:convert';
import 'package:inventory_store_app/data/admin/products_repository.dart';
import 'package:inventory_store_app/models/category_model.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CatalogService {
  CatalogService({ProductsRepository? repository})
    : _repository = repository ?? ProductsRepository();

  final ProductsRepository _repository;

  static List<CategoryModel>? _memCategories;
  static final Map<String, List<ProductModel>> _memProducts = {};

  static void clearCache() {
    _memCategories = null;
    _memProducts.clear();
  }

  Future<List<CategoryModel>> loadCategories() async {
    if (_memCategories != null) return _memCategories!;
    final prefs = await SharedPreferences.getInstance();
    try {
      final categories = await _repository.fetchActiveCategories();
      final cacheData =
          categories
              .map(
                (c) => {
                  'id': c.id,
                  'name': c.name,
                  'description': c.description,
                  'is_active': c.isActive,
                },
              )
              .toList();
      await prefs.setString('cached_admin_categories', jsonEncode(cacheData));
      _memCategories = categories;
      return categories;
    } catch (e) {
      final cached = prefs.getString('cached_admin_categories');
      if (cached != null) {
        final List decoded = jsonDecode(cached);
        final offlineCats =
            decoded
                .map(
                  (e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)),
                )
                .toList();
        _memCategories = offlineCats;
        return offlineCats;
      }
      rethrow;
    }
  }

  Future<ProductModel?> getProductById(String id) async {
    for (final list in _memProducts.values) {
      for (final p in list) {
        if (p.id == id) return p;
      }
    }
    // Si no está en memoria, buscalo en Supabase a través del repositorio.
    // Usamos fetchProducts para re-utilizar la query que trae stock y otros datos básicos.
    try {
      final productsResult = await _repository.fetchProducts();
      final p = productsResult.products.firstWhere((p) => p.id == id);
      return p;
    } catch (_) {
      return null;
    }
  }

  Future<({List<ProductModel> products, int totalCount})> loadProducts({
    String? categoryId,
    String? searchTerm,
    bool isAdmin = false,
    bool? filterIsActive,
    int offset = 0,
    int? limit,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final productsResp = await _repository.fetchProducts(
        categoryId: categoryId,
        searchTerm: searchTerm,
        isAdmin: isAdmin,
        filterIsActive: filterIsActive,
        offset: offset,
        limit: limit,
      );

      if (productsResp.products.isEmpty) {
        return (
          products: <ProductModel>[],
          totalCount: productsResp.totalCount,
        );
      }

      final productIds = productsResp.products
          .map((p) => p.id)
          .toList(growable: false);
      final stockByProduct = await _repository.fetchProductStock(
        productIds: productIds,
      );

      final processedProducts = productsResp.products
          .map(
            (product) =>
                product.copyWith(totalStock: stockByProduct[product.id] ?? 0),
          )
          .toList(growable: false);

      // Eliminado: processedProducts.sort(_compareProductsForCatalog);

      return (products: processedProducts, totalCount: productsResp.totalCount);
    } catch (e) {
      final cached = prefs.getString('cached_admin_products');
      if (cached != null) {
        final List decoded = jsonDecode(cached);
        var offlineProducts =
            decoded
                .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
                .toList();

        if (categoryId != null) {
          offlineProducts =
              offlineProducts.where((p) => p.categoryId == categoryId).toList();
        }
        final term = searchTerm?.trim().toLowerCase() ?? '';
        if (term.isNotEmpty) {
          offlineProducts =
              offlineProducts
                  .where((p) => p.name.toLowerCase().contains(term))
                  .toList();
        }
        return (products: offlineProducts, totalCount: offlineProducts.length);
      }
      throw Exception(
        'Estás sin conexión a internet y no hay catálogo guardado en este dispositivo.',
      );
    }
  }

  Future<
    ({List<ProductModel> products, Map<String, String> matches, int totalCount})
  >
  loadProductsByIngredient({
    required String searchTerm,
    String? categoryId,
    bool isAdmin = false,
    bool? filterIsActive,
    int offset = 0,
    int? limit,
  }) async {
    final result = await _repository.fetchProductsByIngredient(
      searchTerm: searchTerm,
      categoryId: categoryId,
      isAdmin: isAdmin,
      filterIsActive: filterIsActive,
      offset: offset,
      limit: limit,
    );

    if (result.products.isEmpty) return result;

    final productIds = result.products.map((p) => p.id).toList(growable: false);
    final stockByProduct = await _repository.fetchProductStock(
      productIds: productIds,
    );

    final processedProducts = result.products
        .map(
          (product) =>
              product.copyWith(totalStock: stockByProduct[product.id] ?? 0),
        )
        .toList(growable: false);

    return (
      products: processedProducts,
      matches: result.matches,
      totalCount: result.totalCount,
    );
  }

  Future<Map<String, List<ProductVariantModel>>> loadVariantsByProductIds(
    List<String> productIds,
  ) {
    return _repository.fetchVariantsByProductIds(productIds);
  }

  Future<Map<String, int>> loadVariantStockByVariantIds(
    List<String> variantIds,
  ) {
    return _repository.fetchVariantStockByVariantIds(variantIds);
  }

  Future<void> setProductActive({
    required String productId,
    required bool isActive,
  }) {
    return _repository.setProductActive(
      productId: productId,
      isActive: isActive,
    );
  }
}
