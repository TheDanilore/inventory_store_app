import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/services/customer/catalog_service.dart';

class CustomerCatalogProvider extends ChangeNotifier {
  final CatalogService _service = CatalogService();
  static const int pageSize = 24;

  // Search History
  List<String> _searchHistory = [];
  List<String> get searchHistory => _searchHistory;
  bool _isSearchMode = false;
  bool get isSearchMode => _isSearchMode;

  // Categories
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> get categories => _categories;
  String? _selectedCategoryId;
  String? get selectedCategoryId => _selectedCategoryId;

  // Products
  List<ProductModel> _products = [];
  List<ProductModel> get products => _products;
  bool _isInitialLoad = true;
  bool get isInitialLoad => _isInitialLoad;
  bool _isLoadingProducts = false;
  bool get isLoadingProducts => _isLoadingProducts;
  bool _hasMoreProducts = true;
  bool get hasMoreProducts => _hasMoreProducts;
  int _currentPage = 0;
  String? _productsError;
  String? get productsError => _productsError;
  String _searchTerm = '';
  String get searchTerm => _searchTerm;

  Future<void> init() async {
    await _loadSearchHistory();
    await fetchCategories();
    await refreshProducts();
  }

  // --- Search History ---
  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _searchHistory = prefs.getStringList('search_history') ?? [];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> saveSearchTerm(String term) async {
    final t = term.trim();
    if (t.isEmpty) return;
    _searchHistory.removeWhere((item) => item.toLowerCase() == t.toLowerCase());
    _searchHistory.insert(0, t);
    if (_searchHistory.length > 10) {
      _searchHistory = _searchHistory.sublist(0, 10);
    }
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('search_history', _searchHistory);
    } catch (_) {}
  }

  Future<void> clearSearchHistory() async {
    _searchHistory.clear();
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('search_history');
    } catch (_) {}
  }

  void setSearchMode(bool mode) {
    if (_isSearchMode == mode) return;
    _isSearchMode = mode;
    notifyListeners();
  }

  void setSearchTerm(String term) {
    if (_searchTerm == term) return;
    _searchTerm = term;
    refreshProducts();
  }

  // --- Categories ---
  Future<void> fetchCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _categories = await _service.fetchCategories();
      notifyListeners();
      await prefs.setString(
        'cached_customer_categories',
        jsonEncode(_categories),
      );
    } catch (e) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cached = prefs.getString('cached_customer_categories');
        if (cached != null) {
          _categories = List<Map<String, dynamic>>.from(jsonDecode(cached));
          notifyListeners();
        }
      } catch (_) {}
    }
  }

  void selectCategory(String? categoryId) {
    if (_selectedCategoryId == categoryId) return;
    _selectedCategoryId = categoryId;
    refreshProducts();
  }

  // --- Products ---
  Future<void> refreshProducts() async {
    _currentPage = 0;
    _products = [];
    _hasMoreProducts = true;
    _productsError = null;
    _isInitialLoad = true;
    notifyListeners();
    await loadMoreProducts();
  }

  Future<void> loadMoreProducts() async {
    if (_isLoadingProducts || !_hasMoreProducts) return;

    _isLoadingProducts = true;
    _productsError = null;
    notifyListeners();

    try {
      final offset = _currentPage * pageSize;
      final rows = await _service.fetchProducts(
        offset: offset,
        limit: pageSize,
        categoryId: _selectedCategoryId,
        searchTerm: _searchTerm,
      );

      final ids =
          rows.map((e) => e['id'] as String?).whereType<String>().toList();
      final stock = await _service.loadStockByProductIds(ids);

      final fetched = rows
          .map(ProductModel.fromJson)
          .map((p) => p.copyWith(totalStock: (stock[p.id] ?? 0)))
          .toList(growable: false);

      _products.addAll(fetched);
      _products.sort((a, b) {
        final aOut = a.totalStock <= 0;
        final bOut = b.totalStock <= 0;
        if (aOut && !bOut) return 1;
        if (!aOut && bOut) return -1;
        return a.name.compareTo(b.name);
      });

      if (fetched.length < pageSize) {
        _hasMoreProducts = false;
      } else {
        _currentPage++;
      }
    } catch (e) {
      debugPrint('Error cargando productos: $e');
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup') ||
          errStr.contains('connection refused') ||
          errStr.contains('network is unreachable')) {
        _productsError =
            'Comprueba tu conexión a internet e inténtalo de nuevo.';
      } else {
        _productsError =
            'No se pudieron cargar los productos en este momento. Inténtalo de nuevo más tarde.';
      }
    } finally {
      _isLoadingProducts = false;
      _isInitialLoad = false;
      notifyListeners();
    }
  }
}
