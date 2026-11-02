import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. CHIP DE ORDENAMIENTO
// ─────────────────────────────────────────────────────────────────────────────
class SortFilterChip extends StatelessWidget {
  final CatalogSortOption currentSort;
  final ValueChanged<CatalogSortOption> onSelected;

  const SortFilterChip({
    super.key,
    required this.currentSort,
    required this.onSelected,
  });

  bool get _isCustom => currentSort != CatalogSortOption.recent;

  Widget _buildSortItem(
    String label,
    IconData icon,
    bool isSelected,
    bool isDark,
  ) {
    return Row(
      children: [
        Icon(
          isSelected ? Icons.check_circle_rounded : icon,
          size: 16,
          color:
              isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color:
                isSelected
                    ? (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary)
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<CatalogSortOption>(
      tooltip: 'Ordenar productos',
      color: isDark ? AppColors.darkSurface : Colors.white,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      itemBuilder:
          (ctx) => [
            PopupMenuItem(
              value: CatalogSortOption.recent,
              child: _buildSortItem(
                'Recientes',
                Icons.access_time_rounded,
                currentSort == CatalogSortOption.recent,
                isDark,
              ),
            ),
            PopupMenuItem(
              value: CatalogSortOption.nameAsc,
              child: _buildSortItem(
                'Nombre (A-Z)',
                Icons.sort_by_alpha_rounded,
                currentSort == CatalogSortOption.nameAsc,
                isDark,
              ),
            ),
            PopupMenuItem(
              value: CatalogSortOption.priceAsc,
              child: _buildSortItem(
                'Precio: Menor a Mayor',
                Icons.arrow_upward_rounded,
                currentSort == CatalogSortOption.priceAsc,
                isDark,
              ),
            ),
            PopupMenuItem(
              value: CatalogSortOption.priceDesc,
              child: _buildSortItem(
                'Precio: Mayor a Menor',
                Icons.arrow_downward_rounded,
                currentSort == CatalogSortOption.priceDesc,
                isDark,
              ),
            ),
            PopupMenuItem(
              value: CatalogSortOption.highStock,
              child: _buildSortItem(
                'Mayor Stock',
                Icons.inventory_2_rounded,
                currentSort == CatalogSortOption.highStock,
                isDark,
              ),
            ),
          ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color:
              _isCustom
                  ? (isDark
                      ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                      : AppColors.primaryLight)
                  : (isDark
                      ? AppColors.darkSurfaceElevated
                      : AppColors.surface),
          border: Border.all(
            color:
                _isCustom
                    ? (isDark ? const Color(0xFF3B82F6) : AppColors.primary)
                    : (isDark ? AppColors.darkBorder : AppColors.border),
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
              color:
                  _isCustom
                      ? (isDark ? const Color(0xFF60A5FA) : AppColors.primary)
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Text(
              currentSort.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: _isCustom ? FontWeight.w600 : FontWeight.w500,
                color:
                    _isCustom
                        ? (isDark ? const Color(0xFF93C5FD) : AppColors.primary)
                        : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color:
                  _isCustom
                      ? (isDark ? const Color(0xFF60A5FA) : AppColors.primary)
                      : (isDark
                          ? AppColors.darkTextMuted
                          : AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. CHIP DE FILTRO DE STOCK
// ─────────────────────────────────────────────────────────────────────────────
class StockFilterChip extends StatelessWidget {
  final CatalogStockFilter stockFilterState;
  final ValueChanged<CatalogStockFilter> onChanged;

  const StockFilterChip({
    super.key,
    required this.stockFilterState,
    required this.onChanged,
  });

  bool get _hasFilter => stockFilterState != CatalogStockFilter.all;

  Widget _buildItem(
    String label,
    IconData icon,
    bool isSelected,
    bool isDark, {
    Color? color,
  }) {
    return Row(
      children: [
        Icon(
          isSelected ? Icons.check_circle_rounded : icon,
          size: 16,
          color:
              isSelected
                  ? (color ?? AppColors.primary)
                  : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color:
                isSelected
                    ? (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary)
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color? activeBg;
    Color? activeBorder;
    Color? activeText;
    Color? activeIcon;

    if (stockFilterState == CatalogStockFilter.inStock) {
      activeBg =
          isDark
              ? const Color(0xFF064E3B).withValues(alpha: 0.4)
              : AppColors.tealLight;
      activeBorder = isDark ? const Color(0xFF059669) : AppColors.teal;
      activeText = isDark ? const Color(0xFF34D399) : AppColors.tealDark;
      activeIcon = isDark ? const Color(0xFF34D399) : AppColors.teal;
    } else if (stockFilterState == CatalogStockFilter.outOfStock) {
      activeBg =
          isDark
              ? const Color(0xFF7F1D1D).withValues(alpha: 0.4)
              : AppColors.dangerLight;
      activeBorder = isDark ? const Color(0xFFDC2626) : AppColors.danger;
      activeText = isDark ? const Color(0xFFF87171) : const Color(0xFF991B1B);
      activeIcon = isDark ? const Color(0xFFF87171) : AppColors.danger;
    }

    return PopupMenuButton<CatalogStockFilter>(
      tooltip: 'Filtrar por Stock',
      color: isDark ? AppColors.darkSurface : Colors.white,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      itemBuilder:
          (ctx) => [
            PopupMenuItem(
              value: CatalogStockFilter.all,
              child: _buildItem(
                'Todos los productos',
                Icons.all_inclusive_rounded,
                stockFilterState == CatalogStockFilter.all,
                isDark,
              ),
            ),
            PopupMenuItem(
              value: CatalogStockFilter.inStock,
              child: _buildItem(
                'En Stock',
                Icons.check_circle_outline_rounded,
                stockFilterState == CatalogStockFilter.inStock,
                isDark,
                color: isDark ? const Color(0xFF34D399) : AppColors.teal,
              ),
            ),
            PopupMenuItem(
              value: CatalogStockFilter.outOfStock,
              child: _buildItem(
                'Agotados',
                Icons.error_outline_rounded,
                stockFilterState == CatalogStockFilter.outOfStock,
                isDark,
                color: isDark ? const Color(0xFFF87171) : AppColors.danger,
              ),
            ),
          ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color:
              _hasFilter
                  ? activeBg
                  : (isDark
                      ? AppColors.darkSurfaceElevated
                      : AppColors.surface),
          border: Border.all(
            color:
                _hasFilter
                    ? (activeBorder ??
                        (isDark ? AppColors.darkBorder : AppColors.border))
                    : (isDark ? AppColors.darkBorder : AppColors.border),
            width: _hasFilter ? 1.2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _hasFilter
                  ? Icons.inventory_2_rounded
                  : Icons.inventory_2_outlined,
              size: 15,
              color:
                  _hasFilter
                      ? activeIcon
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Text(
              'Stock: ${stockFilterState.label}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: _hasFilter ? FontWeight.w600 : FontWeight.w500,
                color:
                    _hasFilter
                        ? activeText
                        : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 6),
            if (_hasFilter)
              GestureDetector(
                onTap: () {
                  AppFeedbackService.lightImpact();
                  onChanged(CatalogStockFilter.all);
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: activeBorder?.withValues(alpha: isDark ? 0.3 : 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, size: 13, color: activeText),
                ),
              )
            else
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. CHIP DE FILTRO DE ESTADO (ACTIVOS / INACTIVOS)
// ─────────────────────────────────────────────────────────────────────────────
class StatusFilterChip extends StatelessWidget {
  final bool? filterIsActive;
  final ValueChanged<bool?> onChanged;

  const StatusFilterChip({
    super.key,
    required this.filterIsActive,
    required this.onChanged,
  });

  bool get _hasFilter => filterIsActive != null;

  Widget _buildItem(
    String label,
    IconData icon,
    bool isSelected,
    bool isDark, {
    Color? dotColor,
  }) {
    return Row(
      children: [
        if (dotColor != null)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          )
        else
          Icon(
            icon,
            size: 16,
            color:
                isSelected
                    ? AppColors.primary
                    : (isDark ? AppColors.darkTextMuted : AppColors.textMuted),
          ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color:
                isSelected
                    ? (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary)
                    : (isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary),
          ),
        ),
        const Spacer(),
        if (isSelected)
          const Icon(Icons.check_rounded, size: 16, color: AppColors.primary),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String label = 'Estado: Todos';
    if (filterIsActive == true) label = 'Estado: Solo Activos';
    if (filterIsActive == false) label = 'Estado: Solo Inactivos';

    return PopupMenuButton<bool?>(
      tooltip: 'Filtrar por Estado de Catálogo',
      color: isDark ? AppColors.darkSurface : Colors.white,
      onSelected: onChanged,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        side: BorderSide(
          color: isDark ? AppColors.darkBorder : AppColors.border,
        ),
      ),
      itemBuilder:
          (ctx) => [
            PopupMenuItem(
              value: null,
              child: _buildItem(
                'Todos los estados',
                Icons.visibility_rounded,
                filterIsActive == null,
                isDark,
              ),
            ),
            PopupMenuItem(
              value: true,
              child: _buildItem(
                'Solo Activos (Visibles)',
                Icons.check_circle_rounded,
                filterIsActive == true,
                isDark,
                dotColor: AppColors.success,
              ),
            ),
            PopupMenuItem(
              value: false,
              child: _buildItem(
                'Solo Inactivos (Ocultos)',
                Icons.visibility_off_rounded,
                filterIsActive == false,
                isDark,
                dotColor:
                    isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
            ),
          ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color:
              _hasFilter
                  ? (isDark
                      ? const Color(0xFF1E3A8A).withValues(alpha: 0.35)
                      : AppColors.primaryLight)
                  : (isDark
                      ? AppColors.darkSurfaceElevated
                      : AppColors.surface),
          border: Border.all(
            color:
                _hasFilter
                    ? (isDark ? const Color(0xFF3B82F6) : AppColors.primary)
                    : (isDark ? AppColors.darkBorder : AppColors.border),
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
                  color:
                      filterIsActive == true
                          ? AppColors.success
                          : (isDark
                              ? AppColors.darkTextMuted
                              : AppColors.textMuted),
                  shape: BoxShape.circle,
                ),
              )
            else
              Icon(
                Icons.visibility_outlined,
                size: 15,
                color:
                    isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
              ),
            if (!_hasFilter) const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: _hasFilter ? FontWeight.w600 : FontWeight.w500,
                color:
                    _hasFilter
                        ? (isDark ? const Color(0xFF93C5FD) : AppColors.primary)
                        : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary),
              ),
            ),
            const SizedBox(width: 6),
            if (_hasFilter)
              GestureDetector(
                onTap: () {
                  AppFeedbackService.lightImpact();
                  onChanged(null);
                },
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? const Color(0xFF1E3A8A).withValues(alpha: 0.5)
                            : AppColors.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: isDark ? const Color(0xFF93C5FD) : AppColors.primary,
                  ),
                ),
              )
            else
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isDark ? AppColors.darkTextMuted : AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. BOTÓN GLOBAL DE LIMPIAR FILTROS
// ─────────────────────────────────────────────────────────────────────────────
class ClearAllFiltersChip extends StatelessWidget {
  final int activeCount;
  final VoidCallback onClear;

  const ClearAllFiltersChip({
    super.key,
    required this.activeCount,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppFeedbackService.mediumImpact();
          onClear();
        },
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Ink(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color:
                isDark
                    ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
                    : AppColors.errorLight,
            border: Border.all(
              color:
                  isDark
                      ? const Color(0xFFDC2626).withValues(alpha: 0.4)
                      : AppColors.error.withValues(alpha: 0.3),
            ),
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_off_rounded,
                size: 14,
                color: isDark ? const Color(0xFFF87171) : AppColors.error,
              ),
              const SizedBox(width: 6),
              Text(
                activeCount > 1 ? 'Limpiar ($activeCount)' : 'Limpiar',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFFF87171) : AppColors.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
