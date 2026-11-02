import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/products_filter_dropdowns.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_camera_scanner_dialog.dart';

/// Barra de herramientas pro para el catálogo de productos.
/// Encapsula la búsqueda de texto, escáner de códigos de barra (cámara/HID),
/// dropdowns de escritorio, modal de filtros móviles y alternancia de vistas.
class ProductsToolbarWrapper extends StatelessWidget {
  final bool isDesktop;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final bool isTableView;
  final ValueChanged<bool> onToggleTableView;
  final VoidCallback onRefresh;

  const ProductsToolbarWrapper({
    super.key,
    required this.isDesktop,
    required this.searchController,
    required this.searchFocusNode,
    required this.isTableView,
    required this.onToggleTableView,
    required this.onRefresh,
  });

  int _countActiveFilters(AdminCatalogState state) {
    int count = 0;
    if (state.stockFilter != CatalogStockFilter.all) count++;
    if (state.selectedCategoryId != null) count++;
    if (state.selectedBrandId != null) count++;
    if (state.filterIsActive != null) count++;
    if (state.searchByIngredient) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AdminCatalogCubit>();

    return BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
      buildWhen:
          (prev, current) =>
              prev.categories != current.categories ||
              prev.selectedCategoryId != current.selectedCategoryId ||
              prev.filterIsActive != current.filterIsActive ||
              prev.stockFilter != current.stockFilter ||
              prev.sortOption != current.sortOption ||
              prev.searchByIngredient != current.searchByIngredient ||
              prev.totalCount != current.totalCount,
      builder: (context, state) {
        return AdminProToolbar(
          isDesktop: isDesktop,
          searchController: searchController,
          searchFocusNode: searchFocusNode,
          searchHint:
              state.searchByIngredient
                  ? 'Buscar por principio activo / fórmula farmacéutica...'
                  : 'Buscar por título, SKU, código de barras o etiqueta...',
          onSearchChanged: cubit.setSearchTerm,
          onClearSearch: () {
            searchController.clear();
            cubit.clearSearch();
          },
          onSearchSubmitted: (val) => cubit.submitSearch(val),
          onScanBarcode: () async {
            final res = await PosCameraScannerDialog.show(context);
            if (!context.mounted || res == null) return;
            final query = res.product.name;
            searchController.text = query;
            cubit.submitSearch(query, force: true);
            AppSnackbar.show(
              context,
              message: 'Código detectado: ${res.product.name}',
              type: SnackbarType.info,
            );
          },
          searchKeyHint: '/',
          filterWidgets: [
            ProductsCategoryDropdown(
              selectedCategoryId: state.selectedCategoryId,
              categories: state.categories,
              onCategoryChanged: cubit.setCategory,
            ),
            ProductsStatusDropdown(
              filterIsActive: state.filterIsActive,
              onStatusChanged: cubit.setFilterIsActive,
            ),
            ProductsStockDropdown(
              stockFilter: state.stockFilter,
              onStockFilterChanged: cubit.setStockFilter,
            ),
            ProductsSortDropdown(
              sortOption: state.sortOption,
              onSortOptionChanged: cubit.setSortOption,
            ),
          ],
          viewToggleConfig: AdminProViewToggleConfig(
            isTableView: isTableView,
            onToggleTableView: onToggleTableView,
          ),
          onRefresh: onRefresh,
          refreshTooltip: 'Recargar catálogo (Atajo: R)',
          filterGroups: [
            AdminFilterGroup<bool?>(
              title: 'Estado',
              selected: state.filterIsActive,
              defaultValue: null,
              onSelected: cubit.setFilterIsActive,
              options: const [
                AdminFilterOption(value: null, label: 'Todos'),
                AdminFilterOption(
                  value: true,
                  label: 'Activos',
                  color: AppColors.successDark,
                ),
                AdminFilterOption(value: false, label: 'Inactivos'),
              ],
            ),
            AdminFilterGroup<CatalogStockFilter>(
              title: 'Stock',
              selected: state.stockFilter,
              defaultValue: CatalogStockFilter.all,
              onSelected: cubit.setStockFilter,
              options: const [
                AdminFilterOption(
                  value: CatalogStockFilter.all,
                  label: 'Todos',
                ),
                AdminFilterOption(
                  value: CatalogStockFilter.inStock,
                  label: 'En stock',
                  color: AppColors.tealDark,
                ),
                AdminFilterOption(
                  value: CatalogStockFilter.outOfStock,
                  label: 'Agotados',
                  color: AppColors.danger,
                ),
              ],
            ),
            AdminFilterGroup<String?>(
              title: 'Categoría',
              selected: state.selectedCategoryId,
              defaultValue: null,
              onSelected: cubit.setCategory,
              options: [
                const AdminFilterOption(value: null, label: 'Todas'),
                for (final c in state.categories)
                  AdminFilterOption(value: c.id, label: c.name),
              ],
            ),
            AdminFilterGroup<CatalogSortOption>(
              title: 'Ordenar por',
              selected: state.sortOption,
              defaultValue: CatalogSortOption.recent,
              onSelected: cubit.setSortOption,
              options: [
                for (final o in CatalogSortOption.values)
                  AdminFilterOption(value: o, label: o.label),
              ],
            ),
          ],
          mobileExtraFilters: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: state.searchByIngredient,
              onChanged: cubit.toggleSearchByIngredient,
              title: const Text(
                'Buscar por principio activo',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
          mobileFiltersApplyLabel: 'Ver ${state.totalCount} productos',
          activeFiltersCount: _countActiveFilters(state),
        );
      },
    );
  }
}
