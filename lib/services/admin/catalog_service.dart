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
        final offlineCats = decoded
            .map((e) => CategoryModel.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        _memCategories = offlineCats;
        return offlineCats;
      }
      rethrow;
    }
  }

  Future<List<ProductModel>> loadProducts({
    String? categoryId,
    String? searchTerm,
    bool isAdmin = false,
  }) async {
    final cacheKey = '${categoryId ?? 'all'}_$isAdmin';
    if ((searchTerm == null || searchTerm.trim().isEmpty) && _memProducts.containsKey(cacheKey)) {
      return _memProducts[cacheKey]!;
    }

    final prefs = await SharedPreferences.getInstance();
    try {
      final products = await _repository.fetchProducts(
        categoryId: categoryId,
        searchTerm: searchTerm,
        isAdmin: isAdmin,
      );

      if (products.isEmpty) return [];

      final productIds = products.map((p) => p.id).toList(growable: false);
      final stockByProduct = await _repository.fetchProductStock(
        productIds: productIds,
      );

      final processedProducts = products
          .map(
            (product) =>
                product.copyWith(totalStock: stockByProduct[product.id] ?? 0),
          )
          .toList(growable: false);

      processedProducts.sort(_compareProductsForCatalog);

      if (categoryId == null &&
          (searchTerm == null || searchTerm.trim().isEmpty)) {
        await prefs.setString(
          'cached_admin_products',
          jsonEncode(processedProducts.map((p) => p.toJson()).toList()),
        );
      }

      if (searchTerm == null || searchTerm.trim().isEmpty) {
        _memProducts[cacheKey] = processedProducts;
      }

      return processedProducts;
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
        return offlineProducts;
      }
      throw Exception(
        'Estás sin conexión a internet y no hay catálogo guardado en este dispositivo.',
      );
    }
  }

  Future<({List<ProductModel> products, Map<String, String> matches})>
  loadProductsByIngredient({
    required String searchTerm,
    String? categoryId,
    bool isAdmin = false,
  }) async {
    final result = await _repository.fetchProductsByIngredient(
      searchTerm: searchTerm,
      categoryId: categoryId,
      isAdmin: isAdmin,
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

    processedProducts.sort(_compareProductsForCatalog);

    return (products: processedProducts, matches: result.matches);
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

  int _compareProductsForCatalog(ProductModel a, ProductModel b) {
    if (a.isActive && !b.isActive) return -1;
    if (!a.isActive && b.isActive) return 1;

    if (a.isActive && b.isActive) {
      final aAgotado = a.totalStock <= 0;
      final bAgotado = b.totalStock <= 0;

      if (!aAgotado && bAgotado) return -1;
      if (aAgotado && !bAgotado) return 1;
    }

    return 0;
  }
}
