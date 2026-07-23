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

  const CategoryChips({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onSelected,
    this.filterIsActive,
    this.onStatusSelected,
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
                const _SortFilterChip(),
                const SizedBox(width: 8),

                // Chip de Filtro de Stock
                const _StockFilterChip(),
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

class _SortFilterChip extends StatefulWidget {
  const _SortFilterChip();

  @override
  State<_SortFilterChip> createState() => _SortFilterChipState();
}

class _SortFilterChipState extends State<_SortFilterChip> {
  String _currentSort = 'Recientes';

  final List<String> _sortOptions = [
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
      onSelected: (val) => setState(() => _currentSort = val),
      itemBuilder: (ctx) => _sortOptions
          .map(
            (opt) => PopupMenuItem<String>(
              value: opt,
              child: Row(
                children: [
                  Icon(
                    opt == _currentSort
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 16,
                    color: opt == _currentSort
                        ? AppColors.primary
                        : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    opt,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: opt == _currentSort
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
          color: AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.sort_rounded,
              size: 14,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              _currentSort,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Icon(
              Icons.arrow_drop_down_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _StockFilterChip extends StatefulWidget {
  const _StockFilterChip();

  @override
  State<_StockFilterChip> createState() => _StockFilterChipState();
}

class _StockFilterChipState extends State<_StockFilterChip> {
  int _stockFilterState = 0; // 0: Todos, 1: Con Stock, 2: Agotados

  @override
  Widget build(BuildContext context) {
    String label = 'Stock: Todos';
    Color color = AppColors.textSecondary;
    IconData icon = Icons.inventory_2_outlined;

    if (_stockFilterState == 1) {
      label = 'En Stock';
      color = AppColors.success;
      icon = Icons.check_circle_outline_rounded;
    } else if (_stockFilterState == 2) {
      label = 'Agotados';
      color = AppColors.warning;
      icon = Icons.error_outline_rounded;
    }

    return InkWell(
      onTap: () {
        setState(() {
          _stockFilterState = (_stockFilterState + 1) % 3;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _stockFilterState != 0
              ? color.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _stockFilterState != 0
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
                color: _stockFilterState != 0 ? color : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
