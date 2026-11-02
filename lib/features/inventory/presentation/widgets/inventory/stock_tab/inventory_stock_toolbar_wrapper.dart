import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory/inventory_state.dart';

class InventoryStockToolbarWrapper extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;
  final VoidCallback onScanBarcode;
  final bool isTableView;
  final ValueChanged<bool> onToggleTableView;
  final bool isDesktop;
  final bool isTablet;
  final EdgeInsetsGeometry margin;

  const InventoryStockToolbarWrapper({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onScanBarcode,
    required this.isTableView,
    required this.onToggleTableView,
    required this.isDesktop,
    required this.isTablet,
    required this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      InventoryCubit,
      InventoryState,
      (String, String, List<String>, int)
    >(
      selector: (state) {
        if (state is InventoryLoaded) {
          final status =
              state.stockStatusFilter == 'bajo_stock'
                  ? 'low_stock'
                  : state.stockStatusFilter;
          return (
            status,
            state.stockCategoryFilter,
            state.categories,
            state.globalLowStockCount,
          );
        }
        return ('all', 'Todos', const ['Todos'], 0);
      },
      builder: (context, data) {
        final (status, stockCategory, rawCategories, lowStockCount) = data;
        final cubit = context.read<InventoryCubit>();

        final categories = <String>[
          'Todos',
          ...rawCategories.where((c) => c != 'Todos'),
        ];
        final category =
            categories.contains(stockCategory) ? stockCategory : 'Todos';

        final groups = <AdminFilterGroup<dynamic>>[
          AdminFilterGroup<String>(
            title: 'Estado',
            icon: Icons.inventory_2_outlined,
            selected: status,
            defaultValue: 'all',
            options: [
              const AdminFilterOption(value: 'all', label: 'Todos'),
              const AdminFilterOption(
                value: 'in_stock',
                label: 'Con stock',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
              ),
              AdminFilterOption(
                value: 'low_stock',
                label: 'Bajo stock ($lowStockCount)',
                icon: Icons.warning_amber_rounded,
                color: AppColors.warning,
              ),
              const AdminFilterOption(
                value: 'out_of_stock',
                label: 'Agotados',
                icon: Icons.highlight_off_rounded,
                color: AppColors.danger,
              ),
            ],
            onSelected: cubit.setStockStatusFilter,
          ),
          if (categories.length > 1)
            AdminFilterGroup<String>(
              title: 'Categoría',
              icon: Icons.category_outlined,
              selected: category,
              defaultValue: 'Todos',
              options: [
                for (final c in categories)
                  AdminFilterOption(value: c, label: c),
              ],
              onSelected: cubit.setStockCategory,
            ),
        ];

        return AdminProToolbar(
          searchController: searchController,
          searchFocusNode: searchFocusNode,
          searchHint: 'Buscar producto o SKU...',
          searchKeyHint: '/',
          searchOnSubmitOnly: false,
          onSearchChanged: onSearchChanged,
          onSearchSubmitted: onSearchSubmitted,
          onClearSearch: onClearSearch,
          filterGroups: groups,
          activeFiltersCount: groups.where((g) => g.isActive).length,
          onClearFilters: () {
            cubit.setStockStatusFilter('all');
            cubit.setStockCategory('Todos');
          },
          mobileFiltersTitle: 'Filtrar inventario',
          mobileFiltersApplyLabel: 'Ver resultados',
          onRefresh: () {
            cubit.refreshAll();
            AppSnackbar.show(
              context,
              message: 'Actualizando catálogo de inventario...',
              type: SnackbarType.info,
              duration: const Duration(seconds: 2),
            );
          },
          refreshTooltip: 'Recargar existencias',
          viewToggleConfig:
              isDesktop
                  ? AdminProViewToggleConfig(
                    isTableView: isTableView,
                    onToggleTableView: onToggleTableView,
                  )
                  : null,
          onScanBarcode: onScanBarcode,
          scanBarcodeTooltip: 'Escanear código (QR / Barras)',
          enableKeyboardShortcuts: false,
          isDesktop: isDesktop,
          isTablet: isTablet,
          margin: margin,
        );
      },
    );
  }
}
