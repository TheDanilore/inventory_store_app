import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/enums/view_state.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/catalog_form_mutations_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_categories_uc.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_products_uc.dart';
import 'package:inventory_store_app/features/catalog/presentation/utils/pdf/catalog_pdf_generator.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/catalog_dialogs.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'admin_catalog_state.dart';

@injectable
class AdminCatalogCubit extends Cubit<AdminCatalogState> {
  final GetCategoriesUC getCategoriesUC;
  final GetProductsUC getProductsUC;
  final SetProductActiveUC setProductActiveUC;
  final ClearCatalogCacheUC clearCatalogCacheUC;

  Timer? _debounce;

  AdminCatalogCubit({
    required this.getCategoriesUC,
    required this.getProductsUC,
    required this.setProductActiveUC,
    required this.clearCatalogCacheUC,
  }) : super(const AdminCatalogState());

  Future<void> loadInitialData() async {
    await _fetchCategories();
    await refreshProducts();
  }

  // â”€â”€â”€ Categories â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> _fetchCategories() async {
    final result = await getCategoriesUC();
    result.fold(
      (failure) {}, // silently fail
      (cats) => emit(state.copyWith(categories: cats)),
    );
  }

  // â”€â”€â”€ Filters â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  // â”€â”€â”€ Products â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<void> refreshProducts() async {
    emit(state.copyWith(catalogState: ViewState.loading, clearError: true));

    final offset = state.currentPage * AdminCatalogState.pageSize;

    final result = await getProductsUC(
      searchQuery: state.searchTerm,
      categoryId: state.selectedCategoryId,
      isActive: state.filterIsActive,
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
            errStr.contains('sin conexiÃ³n');

        emit(
          state.copyWith(
            catalogState: ViewState.error,
            errorMessage:
                isNetworkError ? 'Sin conexiÃ³n a internet.' : failure.message,
          ),
        );
      },
      (data) {
        emit(
          state.copyWith(
            catalogState:
                data.products.isEmpty ? ViewState.empty : ViewState.success,
            products: data.products,
            totalCount: data.totalCount,
            clearError: true,
          ),
        );
      },
    );
  }

  // â”€â”€â”€ Actions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

  Future<void> exportCatalogPdf(BuildContext context) async {
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

      if (!context.mounted) {
        emit(state.copyWith(actionState: ViewState.initial));
        return;
      }

      result.fold(
        (failure) {
          AppSnackbar.show(
            context,
            message: 'Error al cargar productos: ${failure.message}',
            type: SnackbarType.error,
          );
          emit(state.copyWith(actionState: ViewState.error));
        },
        (data) async {
          if (data.products.isEmpty) {
            AppSnackbar.show(
              context,
              message: 'No hay productos para exportar.',
              type: SnackbarType.error,
            );
            emit(state.copyWith(actionState: ViewState.initial));
            return;
          }

          final allProducts = data.products;
          final visibleProducts = state.products;
          final max50Products = allProducts.take(50).toList();

          // The CatalogDialogs show export options dialogs
          // We need ProductModel for the dialog but we have ProductEntity
          // For now we keep using the old dialog which works with ProductModel
          // This is a valid temporary approach during migration
          final options = await CatalogDialogs.showExportOptionsDialog(
            context,
            max50Products,
            visibleProducts.length,
          );

          if (!context.mounted || options == null) {
            emit(state.copyWith(actionState: ViewState.initial));
            return;
          }

          List<ProductEntity> filteredProducts = [];
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
              message: 'No hay productos seleccionados.',
              type: SnackbarType.error,
            );
            emit(state.copyWith(actionState: ViewState.initial));
            return;
          }

          if (context.mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder:
                  (_) => const AlertDialog(
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 20),
                        Text(
                          'Generando CatÃ¡logo PDF...',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
            );
          }

          await Future.delayed(const Duration(milliseconds: 400));

          try {
            await CatalogPdfGenerator.shareCatalog(
              products: filteredProducts,
              variantsByProduct: const {},
              stockByVariant: const {},
            );
          } finally {
            if (context.mounted) {
              Navigator.of(context, rootNavigator: true).pop();
            }
          }

          emit(state.copyWith(actionState: ViewState.success));
        },
      );
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: 'No se pudo exportar el PDF: $e',
          type: SnackbarType.error,
        );
      }
      emit(state.copyWith(actionState: ViewState.error));
    }
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}

