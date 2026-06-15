import 'package:inventory_store_app/data/admin/products_repository.dart';
import 'package:inventory_store_app/models/category_model.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';

class CatalogService {
  CatalogService({ProductsRepository? repository})
    : _repository = repository ?? ProductsRepository();

  final ProductsRepository _repository;

  Future<List<CategoryModel>> loadCategories() {
    return _repository.fetchActiveCategories();
  }

  // 1. AÑADIMOS EL PARÁMETRO isAdmin AQUÍ
  Future<List<ProductModel>> loadProducts({
    String? categoryId,
    String? searchTerm,
    bool isAdmin = false,
  }) async {
    // 1. Traer los productos primero
    final products = await _repository.fetchProducts(
      categoryId: categoryId,
      searchTerm: searchTerm,
      isAdmin: isAdmin,
    );

    if (products.isEmpty) return [];

    // 2. Traer stock SOLO de los productos visibles (reduce egress)
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
    return processedProducts;
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
