import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/category_model.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/services/admin/catalog_service.dart';

class AdminCatalogProvider extends ChangeNotifier {
  final CatalogService _service = CatalogService();
  Timer? _debounce;

  static const int pageSize = 10;

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

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  final bool _isFetchingMore = false;
  bool get isFetchingMore => _isFetchingMore;

  bool _isLoadingAction = false;
  bool get isLoadingAction => _isLoadingAction;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  String? _error;
  String? get error => _error;

  int _totalCount = 0;
  int get totalCount => _totalCount;

  int _currentPage = 0;
  int get currentPage => _currentPage;

  int get totalPages => _totalCount == 0 ? 1 : (_totalCount / pageSize).ceil();

  AdminCatalogProvider() {
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
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final offset = _currentPage * pageSize;
      final result = await _loadFromService(offset: offset, limit: pageSize);
      _products = result.products;
      _totalCount = result.totalCount;
      _matchedIngredients = result.matches;
      if (result.products.length < pageSize) {
        _hasMore = false;
      } else {
        _hasMore = true;
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
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setPage(int page) {
    if (_currentPage == page) return;
    _currentPage = page;
    refreshProducts();
  }

  // fetchMoreProducts has been replaced by setPage

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
      refreshProducts();
    });
  }

  void setCategory(String? categoryId) {
    if (_selectedCategoryId == categoryId) return;
    _selectedCategoryId = categoryId;
    refreshProducts();
  }

  void toggleSearchByIngredient(bool value) {
    if (_searchByIngredient == value) return;
    _searchByIngredient = value;
    if (value) {
      _selectedCategoryId =
          null; // Clear category when ingredient search is active
    }
    refreshProducts();
  }

  void setFilterIsActive(bool? value) {
    if (_filterIsActive == value) return;
    _filterIsActive = value;
    refreshProducts();
  }

  Future<void> forceSync() async {
    _isLoadingAction = true;
    notifyListeners();
    try {
      CatalogService.clearCache();
      await fetchCategories();
      await refreshProducts();
    } finally {
      _isLoadingAction = false;
      notifyListeners();
    }
  }

  void setLoadingAction(bool value) {
    _isLoadingAction = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
