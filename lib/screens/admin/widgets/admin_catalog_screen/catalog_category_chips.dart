import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/category_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

/// Fila horizontal de chips de categorías y estado para filtrar el catálogo.
class CategoryChips extends StatelessWidget {
  final List<CategoryModel> categories;
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
                  const VerticalDivider(
                    indent: 6,
                    endIndent: 6,
                    color: AppColors.border,
                    width: 16,
                  ),
                  const SizedBox(width: 8),
                ],
                _CategoryChip(
                  label: 'Todas',
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
    Theme.of(context);
    String label = 'Todos';
    Color color = AppColors.textSecondary;
    Color bgColor = AppColors.bg;
    IconData icon = Icons.filter_list_rounded;

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
            // Ciclo: null (Todos) -> true (Activos) -> false (Inactivos) -> null...
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
                color: filterIsActive != null ? color.withValues(alpha: 0.5) : AppColors.border,
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
                color: selected ? primaryColor : AppColors.bg,
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
