import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_categories_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_products_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_product_stock_uc.dart';
import 'customer_catalog_state.dart';

@injectable
class CustomerCatalogCubit extends Cubit<CustomerCatalogState> {
  final GetCategoriesUC getCategoriesUC;
  final GetProductsUC getProductsUC;
  final GetProductStockUC getProductStockUC;

  static const int _pageSize = 24;
  static const String _historyKey = 'search_history';

  CustomerCatalogCubit({
    required this.getCategoriesUC,
    required this.getProductsUC,
    required this.getProductStockUC,
  }) : super(const CustomerCatalogState());

  Future<void> init() async {
    await _loadSearchHistory();
    await _fetchCategories();
    await refreshProducts();
  }

  // ─── Search History ────────────────────────────────────────────────────────

  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final history = prefs.getStringList(_historyKey) ?? [];
      emit(state.copyWith(searchHistory: history));
    } catch (_) {}
  }

  Future<void> saveSearchTerm(String term) async {
    final t = term.trim();
    if (t.isEmpty) return;
    final history = List<String>.from(state.searchHistory);
    history.removeWhere((item) => item.toLowerCase() == t.toLowerCase());
    history.insert(0, t);
    if (history.length > 10) history.removeRange(10, history.length);
    emit(state.copyWith(searchHistory: history));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_historyKey, history);
    } catch (_) {}
  }

  Future<void> clearSearchHistory() async {
    emit(state.copyWith(searchHistory: []));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (_) {}
  }

  void setSearchMode(bool mode) {
    if (state.isSearchMode == mode) return;
    emit(state.copyWith(isSearchMode: mode));
  }

  void setSearchTerm(String term) {
    if (state.searchTerm == term) return;
    emit(state.copyWith(searchTerm: term));
    refreshProducts();
  }

  // ─── Categories ────────────────────────────────────────────────────────────

  Future<void> _fetchCategories() async {
    final result = await getCategoriesUC(activeOnly: true);
    result.fold(
      (failure) {}, // silently fail, categories are optional
      (cats) => emit(state.copyWith(categories: cats)),
    );
  }

  void selectCategory(String? categoryId) {
    if (state.selectedCategoryId == categoryId) return;
    if (categoryId == null) {
      emit(state.copyWith(clearCategory: true));
    } else {
      emit(state.copyWith(selectedCategoryId: categoryId));
    }
    refreshProducts();
  }

  // ─── Products ──────────────────────────────────────────────────────────────

  Future<void> refreshProducts() async {
    emit(
      state.copyWith(
        viewState: ViewState.loading,
        products: [],
        hasMoreProducts: true,
        clearError: true,
      ),
    );
    await _loadPage(0);
  }

  Future<void> loadMoreProducts() async {
    if (state.isLoadingMore || !state.hasMoreProducts) return;
    final nextOffset = state.products.length;
    emit(state.copyWith(isLoadingMore: true));
    await _loadPage(nextOffset);
  }

  Future<void> _loadPage(int offset) async {
    final result = await getProductsUC(
      searchQuery: state.searchTerm,
      categoryId: state.selectedCategoryId,
      isActive: true,
      limit: _pageSize,
      offset: offset,
      sortByPriceAsc: true,
    );

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            viewState: ViewState.error,
            errorMessage: failure.message,
            isLoadingMore: false,
          ),
        );
      },
      (data) async {
        // Enrich with stock
        final ids = data.products.map((p) => p.id).toList();
        Map<String, int> stock = {};
        if (ids.isNotEmpty) {
          final stockResult = await getProductStockUC(productIds: ids);
          stockResult.fold((_) {}, (s) => stock = s);
        }

        final enriched =
            data.products
                .map(
                  (p) => p.copyWith(totalStock: stock[p.id] ?? 0),
                )
                .toList();

        final updated = List<ProductEntity>.from(state.products)
          ..addAll(enriched);

        final hasMore = data.products.length >= _pageSize;

        emit(
          state.copyWith(
            viewState:
                updated.isEmpty ? ViewState.empty : ViewState.success,
            products: updated,
            hasMoreProducts: hasMore,
            isLoadingMore: false,
            clearError: true,
          ),
        );
      },
    );
  }
}
