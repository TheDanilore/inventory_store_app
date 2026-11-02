import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/brand_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/chips/catalog_entity_filter_chips.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/chips/catalog_filter_popups.dart';

export 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/chips/catalog_filter_models.dart';
export 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/chips/catalog_filter_popups.dart';
export 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/chips/catalog_entity_filter_chips.dart';
export 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_catalog_screen/chips/catalog_searchable_picker.dart';

/// Barra de filtros SaaS / ERP de nivel internacional.
///
/// Sustituye la lista horizontal infinita de píldoras por un conjunto coherente
/// de selectores adaptativos (Bottom Sheet en móvil / Diálogo con buscador en desktop)
/// que escala limpiamente desde 3 hasta 500+ categorías y marcas sin fugas de memoria
/// ni jank en teléfonos de gama baja.
class CategoryChips extends StatelessWidget {
  final List<CategoryEntity> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;
  final List<BrandEntity> brands;
  final String? selectedBrandId;
  final ValueChanged<String?>? onBrandSelected;
  final bool? filterIsActive;
  final ValueChanged<bool?>? onStatusSelected;
  final bool showStatusFilter;
  final CatalogSortOption sortOption;
  final ValueChanged<CatalogSortOption> onSortSelected;
  final CatalogStockFilter stockFilter;
  final ValueChanged<CatalogStockFilter> onStockFilterSelected;
  final VoidCallback? onClearAllFilters;

  const CategoryChips({
    super.key,
    required this.categories,
    this.selectedCategoryId,
    required this.onSelected,
    this.brands = const [],
    this.selectedBrandId,
    this.onBrandSelected,
    this.filterIsActive,
    this.onStatusSelected,
    this.showStatusFilter = true,
    this.sortOption = CatalogSortOption.recent,
    required this.onSortSelected,
    this.stockFilter = CatalogStockFilter.all,
    required this.onStockFilterSelected,
    this.onClearAllFilters,
  });

  int get _activeFiltersCount {
    int count = 0;
    if (selectedCategoryId != null) count++;
    if (selectedBrandId != null) count++;
    if (stockFilter != CatalogStockFilter.all) count++;
    if (showStatusFilter && filterIsActive != null) count++;
    if (sortOption != CatalogSortOption.recent) count++;
    return count;
  }

  void _handleClearAll() {
    if (onClearAllFilters != null) {
      onClearAllFilters!();
      return;
    }
    // Fallback si no se provee el callback global
    onSelected(null);
    onBrandSelected?.call(null);
    if (showStatusFilter) {
      onStatusSelected?.call(null);
    }
    onStockFilterSelected(CatalogStockFilter.all);
    onSortSelected(CatalogSortOption.recent);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeCount = _activeFiltersCount;
    final hasActiveFilters = activeCount > 0;

    return Container(
      color: isDark ? AppColors.darkBackground : AppColors.background,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Selector de Ordenamiento
            SortFilterChip(currentSort: sortOption, onSelected: onSortSelected),
            const SizedBox(width: 8),

            // 2. Selector Adaptativo de Categoría
            if (categories.isNotEmpty) ...[
              CategoryFilterChip(
                categories: categories,
                selectedCategoryId: selectedCategoryId,
                onSelected: onSelected,
              ),
              const SizedBox(width: 8),
            ],

            // 3. Selector Adaptativo de Marca
            if (brands.isNotEmpty && onBrandSelected != null) ...[
              BrandFilterChip(
                brands: brands,
                selectedBrandId: selectedBrandId,
                onSelected: onBrandSelected!,
              ),
              const SizedBox(width: 8),
            ],

            // 4. Selector de Stock
            StockFilterChip(
              stockFilterState: stockFilter,
              onChanged: onStockFilterSelected,
            ),
            const SizedBox(width: 8),

            // 5. Selector de Estado (Activos / Inactivos)
            if (showStatusFilter && onStatusSelected != null) ...[
              StatusFilterChip(
                filterIsActive: filterIsActive,
                onChanged: onStatusSelected!,
              ),
              const SizedBox(width: 8),
            ],

            // 6. Botón Global de Limpiar Filtros
            if (hasActiveFilters) ...[
              Container(
                width: 1,
                height: 20,
                color: isDark ? AppColors.darkBorder : AppColors.border,
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
              const SizedBox(width: 4),
              ClearAllFiltersChip(
                activeCount: activeCount,
                onClear: _handleClearAll,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
