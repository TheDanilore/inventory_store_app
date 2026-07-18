import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_form_mutations_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_categories_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_products_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_product_stock_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/export_catalog_pdf_usecase.dart';
import 'admin_catalog_state.dart';

@injectable
class AdminCatalogCubit extends Cubit<AdminCatalogState> {
  final GetCategoriesUC getCategoriesUC;
  final GetProductsUC getProductsUC;
  final SetProductActiveUC setProductActiveUC;
  final ClearCatalogCacheUC clearCatalogCacheUC;
  final ExportCatalogPdfUseCase exportCatalogPdfUC;
  final GetProductStockUC getProductStockUC;

  Timer? _debounce;

  AdminCatalogCubit({
    required this.getCategoriesUC,
    required this.getProductsUC,
    required this.setProductActiveUC,
    required this.clearCatalogCacheUC,
    required this.exportCatalogPdfUC,
    required this.getProductStockUC,
  }) : super(const AdminCatalogState());

  Future<void> loadInitialData() async {
    await _fetchCategories();
    await refreshProducts();
  }

  // Categories

  Future<void> _fetchCategories() async {
    final result = await getCategoriesUC();
    result.fold(
      (failure) {}, // silently fail
      (cats) => emit(state.copyWith(categories: cats)),
    );
  }

  // Filters

  void setSearchTerm(String term) {
    if (state.searchTerm == term) return;
    emit(state.copyWith(searchTerm: term));

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      emit(state.copyWith(currentPage: 0));
      refreshProducts();
    });
  }

  void setCategory(String? categoryId) {
    if (state.selectedCategoryId == categoryId) return;
    if (categoryId == null) {
      emit(state.copyWith(clearCategory: true, currentPage: 0));
    } else {
      emit(state.copyWith(selectedCategoryId: categoryId, currentPage: 0));
    }
    refreshProducts();
  }

  void toggleSearchByIngredient(bool value) {
    if (state.searchByIngredient == value) return;
    emit(
      state.copyWith(
        searchByIngredient: value,
        clearCategory: value,
        currentPage: 0,
      ),
    );
    refreshProducts();
  }

  void setFilterIsActive(bool? value) {
    if (state.filterIsActive == value) return;
    if (value == null) {
      emit(state.copyWith(clearFilterIsActive: true, currentPage: 0));
    } else {
      emit(state.copyWith(filterIsActive: value, currentPage: 0));
    }
    refreshProducts();
  }

  void setPage(int page) {
    if (state.currentPage == page) return;
    emit(state.copyWith(currentPage: page));
    refreshProducts();
  }

  // Products

  Future<void> refreshProducts() async {
    emit(state.copyWith(catalogState: ViewState.loading, clearError: true));

    final offset = state.currentPage * AdminCatalogState.pageSize;

    final result = await getProductsUC(
      searchQuery: state.searchTerm,
      categoryId: state.selectedCategoryId,
      isActive: state.filterIsActive,
      searchByIngredient: state.searchByIngredient,
      limit: AdminCatalogState.pageSize,
      offset: offset,
      sortByPriceAsc: true,
    );

    result.fold(
      (failure) {
        final errStr = failure.message.toLowerCase();
        final isNetworkError =
            errStr.contains('socketexception') ||
            errStr.contains('clientexception') ||
            errStr.contains('failed host lookup') ||
            errStr.contains('offline') ||
            errStr.contains('sin conexión');

        emit(
          state.copyWith(
            catalogState: ViewState.error,
            errorMessage:
                isNetworkError ? 'Sin conexión a internet.' : failure.message,
          ),
        );
      },
      (data) async {
        final ids = data.products.map((p) => p.id).toList();
        Map<String, int> stock = {};
        if (ids.isNotEmpty) {
          final stockResult = await getProductStockUC(productIds: ids);
          stockResult.fold((_) {}, (s) => stock = s);
        }

        final enriched =
            data.products
                .map((p) => p.copyWith(totalStock: stock[p.id] ?? 0))
                .toList();

        emit(
          state.copyWith(
            catalogState:
                enriched.isEmpty ? ViewState.empty : ViewState.success,
            products: enriched,
            totalCount: data.totalCount,
            clearError: true,
          ),
        );
      },
    );
  }

  // Actions

  Future<bool> toggleProductActive(ProductEntity product) async {
    if (state.isLoadingAction) return false;
    final willActivate = !product.isActive;

    emit(state.copyWith(actionState: ViewState.loading));
    final result = await setProductActiveUC(product.id, willActivate);

    return result.fold(
      (failure) {
        emit(
          state.copyWith(
            actionState: ViewState.error,
            errorMessage: failure.message,
          ),
        );
        return false;
      },
      (_) async {
        emit(state.copyWith(actionState: ViewState.success));
        await refreshProducts();
        return true;
      },
    );
  }

  Future<void> forceSync() async {
    emit(state.copyWith(actionState: ViewState.loading));
    await clearCatalogCacheUC();
    await _fetchCategories();
    await refreshProducts();
    emit(state.copyWith(actionState: ViewState.success));
  }

  Future<void> exportCatalogPdf({
    required int optionsMode,
    required List<String> selectedIds,
  }) async {
    if (state.isLoadingAction) return;
    emit(state.copyWith(actionState: ViewState.loading));

    try {
      // Load all matching products (up to 50)
      final result = await getProductsUC(
        searchQuery: state.searchTerm,
        categoryId: state.selectedCategoryId,
        isActive: state.filterIsActive,
        limit: 50,
        offset: 0,
        sortByPriceAsc: true,
      );
      result.fold(
        (failure) {
          emit(
            state.copyWith(
              actionState: ViewState.error,
              errorMessage: 'Error al cargar productos: ${failure.message}',
            ),
          );
        },
        (data) async {
          if (data.products.isEmpty) {
            emit(
              state.copyWith(
                actionState: ViewState.error,
                errorMessage: 'No hay productos para exportar.',
              ),
            );
            return;
          }

          final allProducts = data.products;
          final visibleProducts = state.products;
          final max50Products = allProducts.take(50).toList();

          List<ProductEntity> filteredProducts = [];
          if (optionsMode == 0) {
            filteredProducts = visibleProducts;
          } else if (optionsMode == 1) {
            filteredProducts = max50Products;
          } else if (optionsMode == 2) {
            filteredProducts =
                max50Products.where((p) => selectedIds.contains(p.id)).toList();
          }

          if (filteredProducts.isEmpty) {
            emit(
              state.copyWith(
                actionState: ViewState.error,
                errorMessage: 'No hay productos seleccionados.',
              ),
            );
            return;
          }

          final exportResult = await exportCatalogPdfUC(
            products: filteredProducts,
          );

          exportResult.fold(
            (failure) {
              emit(
                state.copyWith(
                  actionState: ViewState.error,
                  errorMessage: 'Error al generar PDF: ${failure.message}',
                ),
              );
            },
            (_) {
              emit(state.copyWith(actionState: ViewState.success));
            },
          );
        },
      );
    } catch (e) {
      emit(
        state.copyWith(
          actionState: ViewState.error,
          errorMessage: 'Error inesperado: $e',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
