import 'dart:async';

import 'dart:developer' as developer;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_form_mutations_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_categories_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_products_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_product_stock_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/export_catalog_pdf_usecase.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';

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
    result.fold((failure) {
      developer.log(
        'AdminCatalogCubit: Error al cargar categorías: ${failure.message}',
        error: failure,
        stackTrace: StackTrace.current,
      );
    }, (cats) => emit(state.copyWith(categories: cats)));
  }

  // Filters

  void setSearchTerm(String term) {
    if (state.searchTerm == term) return;

    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      emit(state.copyWith(searchTerm: term, currentPage: 0));
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

  void setSortOption(CatalogSortOption option) {
    if (state.sortOption == option) return;
    emit(state.copyWith(sortOption: option, currentPage: 0));
    refreshProducts();
  }

  void setStockFilter(CatalogStockFilter filter) {
    if (state.stockFilter == filter) return;
    emit(state.copyWith(stockFilter: filter, currentPage: 0));
    refreshProducts();
  }

  void setPage(int page) {
    if (state.currentPage == page) return;
    emit(state.copyWith(currentPage: page));
    refreshProducts();
  }

  Future<void> refreshProducts() async {
    _loadProducts(resetPage: true);
  }

  void decrementStockLocal(Map<String, int> soldQuantities) {
    if (state.products.isEmpty) return;

    final updatedProducts =
        state.products.map((product) {
          if (soldQuantities.containsKey(product.id) && product.stockControl) {
            final soldQty = soldQuantities[product.id]!;
            // Aquí restamos el stock de la entidad principal. Si usa lotes/variantes es más complejo,
            // pero para stock general basta con reducir totalStock en UI cache.
            final newStock = product.totalStock - soldQty;
            // Nota: ProductEntity es inmutable, así que creamos un copyWith.
            return product.copyWith(totalStock: newStock < 0 ? 0 : newStock);
          }
          return product;
        }).toList();

    emit(state.copyWith(products: updatedProducts));
  }

  Future<void> _loadProducts({bool resetPage = false}) async {
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
        List<ProductEntity> enriched = data.products;

        // 1. Filtrar por stock
        if (state.stockFilter == CatalogStockFilter.inStock) {
          enriched =
              enriched
                  .where((p) => !p.stockControl || p.totalStock > 0)
                  .toList();
        } else if (state.stockFilter == CatalogStockFilter.outOfStock) {
          enriched =
              enriched
                  .where((p) => p.stockControl && p.totalStock == 0)
                  .toList();
        }

        // 2. Ordenar según sortOption
        if (state.sortOption == CatalogSortOption.nameAsc) {
          enriched.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );
        } else if (state.sortOption == CatalogSortOption.priceAsc) {
          enriched.sort(
            (a, b) =>
                (a.displaySalePrice ?? 0).compareTo(b.displaySalePrice ?? 0),
          );
        } else if (state.sortOption == CatalogSortOption.priceDesc) {
          enriched.sort(
            (a, b) =>
                (b.displaySalePrice ?? 0).compareTo(a.displaySalePrice ?? 0),
          );
        } else if (state.sortOption == CatalogSortOption.highStock) {
          enriched.sort((a, b) => b.totalStock.compareTo(a.totalStock));
        }

        final matchedMap = <String, String>{};
        for (final p in enriched) {
          final ingName =
              (p.details['active_ingredient'] ??
                      p.details['active_ingredients'] ??
                      p.details['principio_activo'] ??
                      p.details['formula'])
                  ?.toString();
          if (ingName != null && ingName.isNotEmpty) {
            matchedMap[p.id] = ingName;
          }
        }

        emit(
          state.copyWith(
            catalogState:
                enriched.isEmpty ? ViewState.empty : ViewState.success,
            products: enriched,
            matchedIngredients: matchedMap,
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
      final resUnwrapped = result.fold((failure) => failure, (data) => data);
      if (resUnwrapped is! ({List<ProductEntity> products, int totalCount})) {
        final failureMsg =
            resUnwrapped is Exception
                ? resUnwrapped.toString()
                : (resUnwrapped as dynamic).message ?? 'Error desconocido';
        developer.log(
          'AdminCatalogCubit: Error al cargar productos para PDF: $failureMsg',
        );
        emit(
          state.copyWith(
            actionState: ViewState.error,
            errorMessage: 'Error al cargar productos: $failureMsg',
          ),
        );
        return;
      }

      final allProducts = resUnwrapped.products;
      if (allProducts.isEmpty) {
        emit(
          state.copyWith(
            actionState: ViewState.error,
            errorMessage: 'No hay productos para exportar.',
          ),
        );
        return;
      }

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

      final exportResult = await exportCatalogPdfUC(products: filteredProducts);

      exportResult.fold(
        (failure) {
          developer.log(
            'AdminCatalogCubit: Error en exportCatalogPdfUC: ${failure.message}',
          );
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
    } catch (e, st) {
      developer.log(
        'AdminCatalogCubit: Error inesperado en exportCatalogPdf',
        error: e,
        stackTrace: st,
      );
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
