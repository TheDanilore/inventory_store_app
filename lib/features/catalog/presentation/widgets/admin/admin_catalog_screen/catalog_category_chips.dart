import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/brand_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';

/// Barra de filtros SaaS / ERP de nivel internacional.
///
/// Sustituye la lista horizontal infinita de píldoras por un conjunto coherente
/// de selectores adaptativos (Bottom Sheet en móvil / Diálogo con buscador en desktop)
/// que escala limpiamente desde 3 hasta 500+ categorías y marcas.
class CategoryChips extends StatelessWidget {
  final List<CategoryEntity> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;
  final List<BrandEntity> brands;
  final String? selectedBrandId;
  final ValueChanged<String?>? onBrandSelected;
  final bool? filterIsActive;
  final ValueChanged<bool?>? onStatusSelected;
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
    if (filterIsActive != null) count++;
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
    onStatusSelected?.call(null);
    onStockFilterSelected(CatalogStockFilter.all);
    onSortSelected(CatalogSortOption.recent);
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _activeFiltersCount;
    final hasActiveFilters = activeCount > 0;

    return Container(
      color: AppColors.background,
      width: double.infinity,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Selector de Ordenamiento
            _SortFilterChip(
              currentSort: sortOption,
              onSelected: onSortSelected,
            ),
            const SizedBox(width: 8),

            // 2. Selector Adaptativo de Categoría
            if (categories.isNotEmpty) ...[
              _CategoryFilterChip(
                categories: categories,
                selectedCategoryId: selectedCategoryId,
                onSelected: onSelected,
              ),
              const SizedBox(width: 8),
            ],

            // 3. Selector Adaptativo de Marca
            if (brands.isNotEmpty && onBrandSelected != null) ...[
              _BrandFilterChip(
                brands: brands,
                selectedBrandId: selectedBrandId,
                onSelected: onBrandSelected!,
              ),
              const SizedBox(width: 8),
            ],

            // 4. Selector de Stock
            _StockFilterChip(
              stockFilterState: stockFilter,
              onChanged: onStockFilterSelected,
            ),
            const SizedBox(width: 8),

            // 5. Selector de Estado (Activos / Inactivos)
            if (onStatusSelected != null) ...[
              _StatusFilterChip(
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
                color: AppColors.border,
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
              const SizedBox(width: 4),
              _ClearAllFiltersChip(
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

// ─────────────────────────────────────────────────────────────────────────────
// 1. CHIP DE ORDENAMIENTO
// ─────────────────────────────────────────────────────────────────────────────
class _SortFilterChip extends StatelessWidget {
  final CatalogSortOption currentSort;
  final ValueChanged<CatalogSortOption> onSelected;

  const _SortFilterChip({
    required this.currentSort,
    required this.onSelected,
  });

  bool get _isCustom => currentSort != CatalogSortOption.recent;

  Widget _buildSortItem(String label, IconData icon, bool isSelected) {
    return Row(
      children: [
        Icon(
          isSelected ? Icons.check_circle_rounded : icon,
          size: 16,
          color: isSelected ? AppColors.primary : AppColors.textMuted,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<CatalogSortOption>(
      tooltip: 'Ordenar productos',
      onSelected: onSelected,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: CatalogSortOption.recent,
          child: _buildSortItem(
            'Recientes',
            Icons.access_time_rounded,
            currentSort == CatalogSortOption.recent,
          ),
        ),
        PopupMenuItem(
          value: CatalogSortOption.nameAsc,
          child: _buildSortItem(
            'Nombre (A-Z)',
            Icons.sort_by_alpha_rounded,
            currentSort == CatalogSortOption.nameAsc,
          ),
        ),
        PopupMenuItem(
          value: CatalogSortOption.priceAsc,
          child: _buildSortItem(
            'Precio: Menor a Mayor',
            Icons.arrow_upward_rounded,
            currentSort == CatalogSortOption.priceAsc,
          ),
        ),
        PopupMenuItem(
          value: CatalogSortOption.priceDesc,
          child: _buildSortItem(
            'Precio: Mayor a Menor',
            Icons.arrow_downward_rounded,
            currentSort == CatalogSortOption.priceDesc,
          ),
        ),
        PopupMenuItem(
          value: CatalogSortOption.highStock,
          child: _buildSortItem(
            'Mayor Stock',
            Icons.inventory_2_rounded,
            currentSort == CatalogSortOption.highStock,
          ),
        ),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _isCustom ? AppColors.primaryLight : AppColors.surface,
          border: Border.all(
            color: _isCustom ? AppColors.primary : AppColors.border,
            width: _isCustom ? 1.2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.swap_vert_rounded,
              size: 16,
              color: _isCustom ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              currentSort.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: _isCustom ? FontWeight.w600 : FontWeight.w500,
                color: _isCustom ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: _isCustom ? AppColors.primary : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. CHIP ADAPTATIVO DE CATEGORÍA (ESCALA A CUALQUIER CANTIDAD)
// ─────────────────────────────────────────────────────────────────────────────
class _CategoryFilterChip extends StatelessWidget {
  final List<CategoryEntity> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;

  const _CategoryFilterChip({
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
  });

  void _openPicker(BuildContext context) {
    HapticFeedback.selectionClick();
    _SearchableItemPicker.show(
      context: context,
      title: 'Categoría',
      allLabel: 'Todas las categorías',
      defaultIcon: Icons.category_rounded,
      items: categories.map((c) => (id: c.id, name: c.name)).toList(),
      selectedId: selectedCategoryId,
      onSelected: onSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedCategory =
        categories.where((c) => c.id == selectedCategoryId).firstOrNull;
    final isSelected = selectedCategory != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPicker(context),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Ink(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryLight : AppColors.surface,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.category_rounded : Icons.category_outlined,
                size: 15,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                isSelected ? 'Categoría: ${selectedCategory.name}' : 'Categoría: Todas',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              if (isSelected)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onSelected(null);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 13,
                      color: AppColors.primary,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. CHIP ADAPTATIVO DE MARCA
// ─────────────────────────────────────────────────────────────────────────────
class _BrandFilterChip extends StatelessWidget {
  final List<BrandEntity> brands;
  final String? selectedBrandId;
  final ValueChanged<String?> onSelected;

  const _BrandFilterChip({
    required this.brands,
    required this.selectedBrandId,
    required this.onSelected,
  });

  void _openPicker(BuildContext context) {
    HapticFeedback.selectionClick();
    _SearchableItemPicker.show(
      context: context,
      title: 'Marca',
      allLabel: 'Todas las marcas',
      defaultIcon: Icons.verified_rounded,
      items: brands.map((b) => (id: b.id, name: b.name)).toList(),
      selectedId: selectedBrandId,
      onSelected: onSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedBrand =
        brands.where((b) => b.id == selectedBrandId).firstOrNull;
    final isSelected = selectedBrand != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openPicker(context),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Ink(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.infoLight : AppColors.surface,
            border: Border.all(
              color: isSelected ? AppColors.info : AppColors.border,
              width: isSelected ? 1.2 : 1,
            ),
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.verified_rounded : Icons.verified_outlined,
                size: 15,
                color: isSelected ? AppColors.info : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                isSelected ? 'Marca: ${selectedBrand.name}' : 'Marca: Todas',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0369A1) : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              if (isSelected)
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onSelected(null);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 13,
                      color: Color(0xFF0369A1),
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. CHIP DE FILTRO DE STOCK
// ─────────────────────────────────────────────────────────────────────────────
class _StockFilterChip extends StatelessWidget {
  final CatalogStockFilter stockFilterState;
  final ValueChanged<CatalogStockFilter> onChanged;

  const _StockFilterChip({
    required this.stockFilterState,
    required this.onChanged,
  });

  bool get _hasFilter => stockFilterState != CatalogStockFilter.all;

  Widget _buildItem(String label, IconData icon, bool isSelected, {Color? color}) {
    return Row(
      children: [
        Icon(
          isSelected ? Icons.check_circle_rounded : icon,
          size: 16,
          color: isSelected ? (color ?? AppColors.primary) : AppColors.textMuted,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Color? activeBg;
    Color? activeBorder;
    Color? activeText;
    Color? activeIcon;

    if (stockFilterState == CatalogStockFilter.inStock) {
      activeBg = AppColors.tealLight;
      activeBorder = AppColors.teal;
      activeText = AppColors.tealDark;
      activeIcon = AppColors.teal;
    } else if (stockFilterState == CatalogStockFilter.outOfStock) {
      activeBg = AppColors.dangerLight;
      activeBorder = AppColors.danger;
      activeText = const Color(0xFF991B1B);
      activeIcon = AppColors.danger;
    }

    return PopupMenuButton<CatalogStockFilter>(
      tooltip: 'Filtrar por Stock',
      onSelected: onChanged,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: CatalogStockFilter.all,
          child: _buildItem(
            'Todos los productos',
            Icons.all_inclusive_rounded,
            stockFilterState == CatalogStockFilter.all,
          ),
        ),
        PopupMenuItem(
          value: CatalogStockFilter.inStock,
          child: _buildItem(
            'En Stock',
            Icons.check_circle_outline_rounded,
            stockFilterState == CatalogStockFilter.inStock,
            color: AppColors.teal,
          ),
        ),
        PopupMenuItem(
          value: CatalogStockFilter.outOfStock,
          child: _buildItem(
            'Agotados',
            Icons.error_outline_rounded,
            stockFilterState == CatalogStockFilter.outOfStock,
            color: AppColors.danger,
          ),
        ),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _hasFilter ? activeBg : AppColors.surface,
          border: Border.all(
            color: _hasFilter ? (activeBorder ?? AppColors.border) : AppColors.border,
            width: _hasFilter ? 1.2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _hasFilter ? Icons.inventory_2_rounded : Icons.inventory_2_outlined,
              size: 15,
              color: _hasFilter ? activeIcon : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              'Stock: ${stockFilterState.label}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: _hasFilter ? FontWeight.w600 : FontWeight.w500,
                color: _hasFilter ? activeText : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            if (_hasFilter)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onChanged(CatalogStockFilter.all);
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: activeBorder?.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: activeText,
                  ),
                ),
              )
            else
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. CHIP DE FILTRO DE ESTADO (ACTIVOS / INACTIVOS)
// ─────────────────────────────────────────────────────────────────────────────
class _StatusFilterChip extends StatelessWidget {
  final bool? filterIsActive;
  final ValueChanged<bool?> onChanged;

  const _StatusFilterChip({
    required this.filterIsActive,
    required this.onChanged,
  });

  bool get _hasFilter => filterIsActive != null;

  Widget _buildItem(String label, IconData icon, bool isSelected, {Color? dotColor}) {
    return Row(
      children: [
        if (dotColor != null)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          )
        else
          Icon(icon, size: 16, color: isSelected ? AppColors.primary : AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        if (isSelected)
          const Icon(
            Icons.check_rounded,
            size: 16,
            color: AppColors.primary,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    String label = 'Estado: Todos';
    if (filterIsActive == true) label = 'Estado: Solo Activos';
    if (filterIsActive == false) label = 'Estado: Solo Inactivos';

    return PopupMenuButton<bool?>(
      tooltip: 'Filtrar por Estado de Catálogo',
      onSelected: onChanged,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: null,
          child: _buildItem(
            'Todos los estados',
            Icons.visibility_rounded,
            filterIsActive == null,
          ),
        ),
        PopupMenuItem(
          value: true,
          child: _buildItem(
            'Solo Activos (Visibles)',
            Icons.check_circle_rounded,
            filterIsActive == true,
            dotColor: AppColors.success,
          ),
        ),
        PopupMenuItem(
          value: false,
          child: _buildItem(
            'Solo Inactivos (Ocultos)',
            Icons.visibility_off_rounded,
            filterIsActive == false,
            dotColor: AppColors.textMuted,
          ),
        ),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _hasFilter ? AppColors.primaryLight : AppColors.surface,
          border: Border.all(
            color: _hasFilter ? AppColors.primary : AppColors.border,
            width: _hasFilter ? 1.2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_hasFilter)
              Container(
                width: 7,
                height: 7,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: filterIsActive == true ? AppColors.success : AppColors.textMuted,
                  shape: BoxShape.circle,
                ),
              )
            else
              const Icon(
                Icons.visibility_outlined,
                size: 15,
                color: AppColors.textSecondary,
              ),
            if (!_hasFilter) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: _hasFilter ? FontWeight.w600 : FontWeight.w500,
                color: _hasFilter ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            if (_hasFilter)
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onChanged(null);
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: AppColors.primary,
                  ),
                ),
              )
            else
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. BOTÓN GLOBAL DE LIMPIAR FILTROS
// ─────────────────────────────────────────────────────────────────────────────
class _ClearAllFiltersChip extends StatelessWidget {
  final int activeCount;
  final VoidCallback onClear;

  const _ClearAllFiltersChip({
    required this.activeCount,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onClear();
        },
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Ink(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.errorLight,
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.filter_alt_off_rounded,
                size: 14,
                color: AppColors.error,
              ),
              const SizedBox(width: 6),
              Text(
                activeCount > 1 ? 'Limpiar ($activeCount)' : 'Limpiar',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. COMPONENTE ADAPTATIVO MODAL / BOTTOM SHEET CON BUSCADOR
// ─────────────────────────────────────────────────────────────────────────────
class _SearchableItemPicker extends StatefulWidget {
  final String title;
  final String allLabel;
  final IconData defaultIcon;
  final List<({String? id, String name})> items;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  const _SearchableItemPicker({
    required this.title,
    required this.allLabel,
    required this.defaultIcon,
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String allLabel,
    required IconData defaultIcon,
    required List<({String? id, String name})> items,
    required String? selectedId,
    required ValueChanged<String?> onSelected,
  }) async {
    final isMobile = MediaQuery.of(context).size.width < 650;
    if (isMobile) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _SearchableItemPicker(
          title: title,
          allLabel: allLabel,
          defaultIcon: defaultIcon,
          items: items,
          selectedId: selectedId,
          onSelected: onSelected,
        ),
      );
    } else {
      await showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: AppColors.surface,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radius),
            side: const BorderSide(color: AppColors.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380, maxHeight: 480),
            child: _SearchableItemPicker(
              title: title,
              allLabel: allLabel,
              defaultIcon: defaultIcon,
              items: items,
              selectedId: selectedId,
              onSelected: onSelected,
            ),
          ),
        ),
      );
    }
  }

  @override
  State<_SearchableItemPicker> createState() => _SearchableItemPickerState();
}

class _SearchableItemPickerState extends State<_SearchableItemPicker> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 650;
    final showSearch = widget.items.length > 5;

    final filteredItems = _query.isEmpty
        ? widget.items
        : widget.items
            .where((i) => i.name.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Drag Handle (Solo en móvil) ───────────────────────────────────
        if (isMobile) ...[
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ] else
          const SizedBox(height: 16),

        // ── Cabecera con Título y Acción de Limpiar ───────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const Spacer(),
              if (widget.selectedId != null)
                TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.onSelected(null);
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.error,
                  ),
                  child: const Text(
                    'Limpiar',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (!isMobile)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textMuted,
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Cerrar',
                ),
            ],
          ),
        ),

        // ── Buscador Dinámico (Si hay más de 5 elementos) ─────────────────
        if (showSearch) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: !isMobile,
              onChanged: (val) => setState(() => _query = val.trim()),
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Buscar en ${widget.title.toLowerCase()}...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ],

        const Divider(height: 1, color: AppColors.border),

        // ── Lista de Opciones ─────────────────────────────────────────────
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: filteredItems.length + (_query.isEmpty ? 1 : 0),
            separatorBuilder: (_, _) =>
                const Divider(height: 1, indent: 48, color: AppColors.divider),
            itemBuilder: (context, index) {
              // Primera opción: "Todas las ..." (solo si no hay búsqueda activa)
              if (_query.isEmpty && index == 0) {
                final isAllSelected = widget.selectedId == null;
                return _buildOptionTile(
                  title: widget.allLabel,
                  isSelected: isAllSelected,
                  icon: Icons.all_inclusive_rounded,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onSelected(null);
                    Navigator.of(context).pop();
                  },
                );
              }

              final itemIndex = _query.isEmpty ? index - 1 : index;
              final item = filteredItems[itemIndex];
              final isSelected = widget.selectedId == item.id;

              return _buildOptionTile(
                title: item.name,
                isSelected: isSelected,
                icon: widget.defaultIcon,
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onSelected(item.id);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),

        if (isMobile) SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );

    if (isMobile) {
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(top: false, child: content),
      );
    }

    return content;
  }

  Widget _buildOptionTile({
    required String title,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.05)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 46),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (isSelected)
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
