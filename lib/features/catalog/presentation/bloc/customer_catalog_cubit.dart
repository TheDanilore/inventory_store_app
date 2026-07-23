import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/catalog_search_repository.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_categories_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_products_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_product_stock_uc.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/customer_catalog_state.dart';

@injectable
class CustomerCatalogCubit extends Cubit<CustomerCatalogState> {
  final GetCategoriesUC getCategoriesUC;
  final GetProductsUC getProductsUC;
  final GetProductStockUC getProductStockUC;

  /// Repositorio inyectado únicamente para las operaciones de historial de búsqueda.
  /// SharedPreferences permanece en la capa de datos — no en el Cubit.
  final CatalogSearchRepository _catalogRepository;

  static const int _pageSize = 24;

  CustomerCatalogCubit({
    required this.getCategoriesUC,
    required this.getProductsUC,
    required this.getProductStockUC,
    required CatalogSearchRepository catalogRepository,
  }) : _catalogRepository = catalogRepository,
       super(const CustomerCatalogState());

  Future<void> loadInitialData() async {
    await _loadSearchHistory();
    await _fetchCategories();
    await refreshProducts();
  }

  // ─── Search History ────────────────────────────────────────────────────────

  Future<void> _loadSearchHistory() async {
    final history = await _catalogRepository.getSearchHistory();
    emit(state.copyWith(searchHistory: history));
  }

  Future<void> saveSearchTerm(String term) async {
    final t = term.trim();
    if (t.isEmpty) return;
    final history = List<String>.from(state.searchHistory);
    history.removeWhere((item) => item.toLowerCase() == t.toLowerCase());
    history.insert(0, t);
    if (history.length > 10) history.removeRange(10, history.length);
    emit(state.copyWith(searchHistory: history));
    await _catalogRepository.saveSearchHistory(history);
  }

  Future<void> clearSearchHistory() async {
    emit(state.copyWith(searchHistory: []));
    await _catalogRepository.clearSearchHistory();
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
          stockResult.fold(
            (l) => debugPrint(
              'CustomerCatalogCubit: error loading stock -> ${l.message}',
            ),
            (s) => stock = s,
          );
        }

        final enriched =
            data.products
                .map((p) => p.copyWith(totalStock: stock[p.id] ?? p.totalStock))
                .toList();

        // Ordenamiento prioritario estándar E-Commerce: con stock primero
        enriched.sort((a, b) {
          final aAvailable = !a.stockControl || a.totalStock > 0;
          final bAvailable = !b.stockControl || b.totalStock > 0;
          if (aAvailable && !bAvailable) return -1;
          if (!aAvailable && bAvailable) return 1;
          return 0;
        });

        final updated = List<ProductEntity>.from(state.products)
          ..addAll(enriched);

        final hasMore = data.products.length >= _pageSize;

        emit(
          state.copyWith(
            viewState: updated.isEmpty ? ViewState.empty : ViewState.success,
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
