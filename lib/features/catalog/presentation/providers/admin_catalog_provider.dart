import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/catalog/data/models/category_model.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';
import 'package:inventory_store_app/features/catalog/data/repositories/catalog_service.dart';
import 'package:inventory_store_app/features/catalog/data/repositories/catalog_pdf_generator.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/screens/admin/widgets/admin_catalog_screen/catalog_dialogs.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class AdminCatalogProvider extends ChangeNotifier {
  final CatalogService _service;
  Timer? _debounce;

  static const int pageSize = 24;

  List<CategoryModel> _categories = [];
  List<CategoryModel> get categories => _categories;

  List<ProductModel> _products = [];
  List<ProductModel> get products => _products;

  Map<String, String> _matchedIngredients = {};
  Map<String, String> get matchedIngredients => _matchedIngredients;

  String? _selectedCategoryId;
  String? get selectedCategoryId => _selectedCategoryId;

  String _searchTerm = '';
  String get searchTerm => _searchTerm;

  bool _searchByIngredient = false;
  bool get searchByIngredient => _searchByIngredient;

  bool? _filterIsActive;
  bool? get filterIsActive => _filterIsActive;

  ViewState _catalogState = ViewState.initial;
  ViewState get catalogState => _catalogState;

  ViewState _actionState = ViewState.initial;
  ViewState get actionState => _actionState;

  bool get isLoading => _catalogState == ViewState.loading;
  bool get isLoadingAction => _actionState == ViewState.loading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  String? _error;
  String? get error => _error;

  int _totalCount = 0;
  int get totalCount => _totalCount;

  int _currentPage = 0;
  int get currentPage => _currentPage;

  int get totalPages => _totalCount == 0 ? 1 : (_totalCount / pageSize).ceil();

  AdminCatalogProvider({CatalogService? service})
    : _service = service ?? CatalogService() {
    _init();
  }

  void _init() async {
    await fetchCategories();
    await refreshProducts();
  }

  Future<void> fetchCategories() async {
    try {
      _categories = await _service.loadCategories();
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<void> refreshProducts() async {
    _catalogState = ViewState.loading;
    _error = null;
    notifyListeners();

    try {
      final offset = _currentPage * pageSize;
      final result = await _loadFromService(offset: offset, limit: pageSize);
      _products = result.products;
      _totalCount = result.totalCount;
      _matchedIngredients = result.matches;

      _hasMore = result.products.length >= pageSize;

      if (_products.isEmpty) {
        _catalogState = ViewState.empty;
      } else {
        _catalogState = ViewState.success;
      }
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('offline') ||
          errStr.contains('sin conexión')) {
        _error = 'Sin conexión a internet.';
      } else {
        _error = e.toString();
      }
      _catalogState = ViewState.error;
    } finally {
      notifyListeners();
    }
  }

  void setPage(int page) {
    if (_currentPage == page) return;
    _currentPage = page;
    refreshProducts();
  }

  Future<
    ({List<ProductModel> products, Map<String, String> matches, int totalCount})
  >
  _loadFromService({required int offset, required int limit}) async {
    if (_searchByIngredient) {
      if (_searchTerm.trim().isNotEmpty) {
        return await _service.loadProductsByIngredient(
          searchTerm: _searchTerm.trim(),
          categoryId: _selectedCategoryId,
          isAdmin: true,
          filterIsActive: _filterIsActive,
          offset: offset,
          limit: limit,
        );
      } else {
        return (
          products: <ProductModel>[],
          matches: <String, String>{},
          totalCount: 0,
        );
      }
    }

    final productsResp = await _service.loadProducts(
      categoryId: _selectedCategoryId,
      searchTerm: _searchTerm.trim(),
      isAdmin: true,
      filterIsActive: _filterIsActive,
      offset: offset,
      limit: limit,
    );
    return (
      products: productsResp.products,
      matches: <String, String>{},
      totalCount: productsResp.totalCount,
    );
  }

  void setSearchTerm(String term) {
    if (_searchTerm == term) return;
    _searchTerm = term;

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _currentPage = 0;
      refreshProducts();
    });
  }

  void setCategory(String? categoryId) {
    if (_selectedCategoryId == categoryId) return;
    _selectedCategoryId = categoryId;
    _currentPage = 0;
    refreshProducts();
  }

  void toggleSearchByIngredient(bool value) {
    if (_searchByIngredient == value) return;
    _searchByIngredient = value;
    if (value) {
      _selectedCategoryId = null;
    }
    _currentPage = 0;
    refreshProducts();
  }

  void setFilterIsActive(bool? value) {
    if (_filterIsActive == value) return;
    _filterIsActive = value;
    _currentPage = 0;
    refreshProducts();
  }

  Future<void> forceSync() async {
    _actionState = ViewState.loading;
    notifyListeners();
    try {
      await CatalogService.clearCache();
      await fetchCategories();
      await refreshProducts();
      _actionState = ViewState.success;
    } catch (_) {
      _actionState = ViewState.error;
    } finally {
      notifyListeners();
    }
  }

  // --- NUEVOS MÉTODOS DE NEGOCIO ---

  Future<bool> toggleProductActive(ProductModel product) async {
    if (isLoadingAction) return false;
    final willActivate = !product.isActive;

    _actionState = ViewState.loading;
    notifyListeners();

    try {
      await _service.setProductActive(
        productId: product.id,
        isActive: willActivate,
      );
      _actionState = ViewState.success;
      await refreshProducts();
      return true;
    } catch (e) {
      _error = e.toString();
      _actionState = ViewState.error;
      notifyListeners();
      return false;
    }
  }

  Future<void> exportCatalogPdf(BuildContext context) async {
    if (isLoadingAction) return;

    _actionState = ViewState.loading;
    notifyListeners();

    try {
      final allProductsResult = await _service.loadProducts(
        categoryId: _selectedCategoryId,
        searchTerm: _searchTerm,
        isAdmin: true,
        filterIsActive: _filterIsActive,
      );
      final allProducts = allProductsResult.products;

      if (!context.mounted) return;

      if (allProducts.isEmpty) {
        AppSnackbar.show(
          context,
          message: 'No hay productos para exportar.',
          type: SnackbarType.error,
        );
        _actionState = ViewState.initial;
        notifyListeners();
        return;
      }

      final visibleProducts = _products;
      final max50Products = allProducts.take(50).toList();

      final options = await CatalogDialogs.showExportOptionsDialog(
        context,
        max50Products,
        visibleProducts.length,
      );

      if (!context.mounted || options == null) {
        _actionState = ViewState.initial;
        notifyListeners();
        return;
      }

      List<ProductModel> filteredProducts = [];
      if (options.mode == 0) {
        filteredProducts = visibleProducts;
      } else if (options.mode == 1) {
        filteredProducts = max50Products;
      } else if (options.mode == 2) {
        filteredProducts =
            max50Products
                .where((p) => options.selectedIds.contains(p.id))
                .toList();
      }

      if (filteredProducts.isEmpty) {
        AppSnackbar.show(
          context,
          message: 'No hay productos seleccionados para exportar.',
          type: SnackbarType.error,
        );
        _actionState = ViewState.initial;
        notifyListeners();
        return;
      }

      // Dialog bloqueante controlado
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (dialogCtx) => const AlertDialog(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Generando Catálogo PDF...',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
      );

      await Future.delayed(const Duration(milliseconds: 400));

      try {
        final productIds = filteredProducts.map((p) => p.id).toList();
        final variantsByProduct = await _service.loadVariantsByProductIds(
          productIds,
        );
        final allVariantIds =
            variantsByProduct.values
                .expand((v) => v)
                .map((v) => v.id)
                .whereType<String>()
                .toList();
        final stockByVariant = await _service.loadVariantStockByVariantIds(
          allVariantIds,
        );

        await CatalogPdfGenerator.shareCatalog(
          products: filteredProducts,
          variantsByProduct: variantsByProduct,
          stockByVariant: stockByVariant,
        );
      } finally {
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }

      _actionState = ViewState.success;
    } catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: 'No se pudo exportar el PDF: $e',
        type: SnackbarType.error,
      );
      _actionState = ViewState.error;
    } finally {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
