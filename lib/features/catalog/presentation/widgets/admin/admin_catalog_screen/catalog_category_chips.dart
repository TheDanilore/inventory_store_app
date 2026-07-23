import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Fila horizontal de chips de ordenamiento, filtros rápidos (Recién Creados, Activos, Con Stock) y categorías.
class CategoryChips extends StatelessWidget {
  final List<CategoryEntity> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelected;
  final bool? filterIsActive;
  final ValueChanged<bool?>? onStatusSelected;
  final String sortOption;
  final ValueChanged<String>? onSortSelected;
  final int stockFilter;
  final ValueChanged<int>? onStockFilterSelected;

  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
    this.filterIsActive,
    this.onStatusSelected,
    this.sortOption = 'Recientes',
    this.onSortSelected,
    this.stockFilter = 0,
    this.onStockFilterSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          const Divider(height: 1, color: AppColors.border),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (onStatusSelected != null) ...[
                  _StatusFilterChip(
                    filterIsActive: filterIsActive,
                    onChanged: onStatusSelected!,
                  ),
                  const SizedBox(width: 8),
                ],

                // Chip de Ordenamiento
                _SortFilterChip(
                  currentSort: sortOption,
                  onSelected: onSortSelected ?? (_) {},
                ),
                const SizedBox(width: 8),

                // Chip de Filtro de Stock
                _StockFilterChip(
                  stockFilterState: stockFilter,
                  onChanged: onStockFilterSelected ?? (_) {},
                ),
                const SizedBox(width: 8),

                const VerticalDivider(
                  indent: 6,
                  endIndent: 6,
                  color: AppColors.border,
                  width: 16,
                ),
                const SizedBox(width: 8),

                // Chip por defecto: Óptimo (Todas)
                _CategoryChip(
                  label: 'Óptimo (Todas)',
                  selected: selectedCategoryId == null,
                  onTap: () => onSelected(null),
                ),

                ...categories.map(
                  (cat) => _CategoryChip(
                    label: cat.name,
                    selected: selectedCategoryId == cat.id,
                    onTap: () => onSelected(cat.id),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final bool? filterIsActive;
  final ValueChanged<bool?> onChanged;

  const _StatusFilterChip({
    required this.filterIsActive,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    String label = 'Todos';
    Color color = AppColors.textSecondary;
    Color bgColor = AppColors.background;
    IconData icon = Icons.tune_rounded;

    if (filterIsActive == true) {
      label = 'Activos';
      color = AppColors.success;
      bgColor = AppColors.success.withValues(alpha: 0.1);
      icon = Icons.check_circle_outline_rounded;
    } else if (filterIsActive == false) {
      label = 'Inactivos';
      color = AppColors.danger;
      bgColor = AppColors.danger.withValues(alpha: 0.1);
      icon = Icons.cancel_outlined;
    }

    return Semantics(
      label: 'Filtro de estado: $label. Tocar para cambiar.',
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Ciclo de filtrado: null (Todos) -> true (Activos) -> false (Inactivos) -> null...
            if (filterIsActive == null) {
              onChanged(true);
            } else if (filterIsActive == true) {
              onChanged(false);
            } else {
              onChanged(null);
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    filterIsActive != null
                        ? color.withValues(alpha: 0.5)
                        : AppColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Semantics(
      label: 'Categoría $label',
      selected: selected,
      button: true,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? primaryColor : AppColors.background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? primaryColor : AppColors.border,
                ),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SortFilterChip extends StatelessWidget {
  final String currentSort;
  final ValueChanged<String> onSelected;

  const _SortFilterChip({
    required this.currentSort,
    required this.onSelected,
  });

  static const List<String> _sortOptions = [
    'Recientes',
    'Nombre (A-Z)',
    'Precio: Menor a Mayor',
    'Precio: Mayor a Menor',
    'Mayor Stock',
  ];

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Ordenar por',
      onSelected: onSelected,
      itemBuilder: (ctx) => _sortOptions
          .map(
            (opt) => PopupMenuItem<String>(
              value: opt,
              child: Row(
                children: [
                  Icon(
                    opt == currentSort
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: opt == currentSort
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    opt,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: opt == currentSort
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: currentSort != 'Recientes'
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: currentSort != 'Recientes'
                ? AppColors.primary.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sort_rounded,
              size: 14,
              color: currentSort != 'Recientes'
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              currentSort,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: currentSort != 'Recientes'
                    ? AppColors.primary
                    : AppColors.textPrimary,
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: currentSort != 'Recientes'
                  ? AppColors.primary
                  : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _StockFilterChip extends StatelessWidget {
  final int stockFilterState;
  final ValueChanged<int> onChanged;

  const _StockFilterChip({
    required this.stockFilterState,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    String label = 'Stock: Todos';
    Color color = AppColors.textSecondary;
    IconData icon = Icons.inventory_2_outlined;

    if (stockFilterState == 1) {
      label = 'En Stock';
      color = AppColors.success;
      icon = Icons.check_circle_outline_rounded;
    } else if (stockFilterState == 2) {
      label = 'Agotados';
      color = AppColors.warning;
      icon = Icons.error_outline_rounded;
    }

    return InkWell(
      onTap: () {
        final nextState = (stockFilterState + 1) % 3;
        onChanged(nextState);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: stockFilterState != 0
              ? color.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: stockFilterState != 0
                ? color.withValues(alpha: 0.5)
                : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: stockFilterState != 0 ? color : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
