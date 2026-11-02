import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

enum AttributeFilter { all, withValues, withoutValues }

/// Barra de comandos, búsqueda y filtros por estado de valores de propiedades.
class AttributeCommandBar extends StatelessWidget {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final String searchQuery;
  final AttributeFilter activeFilter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<AttributeFilter> onFilterChanged;
  final int totalAttributes;
  final int totalValues;
  final bool isMobile;

  const AttributeCommandBar({
    super.key,
    required this.searchController,
    required this.searchFocusNode,
    required this.searchQuery,
    required this.activeFilter,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onFilterChanged,
    required this.totalAttributes,
    required this.totalValues,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Search Input
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  onChanged: onSearchChanged,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText:
                        isMobile
                            ? 'Buscar propiedad o valor...'
                            : 'Buscar propiedad o valor (Ej: Talla, Spiderman, Litro)...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon:
                        searchQuery.isNotEmpty
                            ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 16),
                              tooltip: 'Limpiar búsqueda',
                              onPressed: onClearSearch,
                            )
                            : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Stat Badges
            _StatBadge(
              label:
                  '$totalAttributes ${totalAttributes == 1 ? 'propiedad' : 'propiedades'}',
              icon: Icons.category_outlined,
              color: AppColors.primary,
            ),
            if (!isMobile) ...[
              const SizedBox(width: 8),
              _StatBadge(
                label: '$totalValues valores',
                icon: Icons.label_outline_rounded,
                color: AppColors.info,
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),

        // Filter Pills: [ Todas ] [ Con valores ] [ Sin valores ]
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterChip(
                label: 'Todas',
                filter: AttributeFilter.all,
                isSelected: activeFilter == AttributeFilter.all,
                onSelected: () => onFilterChanged(AttributeFilter.all),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Con valores',
                filter: AttributeFilter.withValues,
                isSelected: activeFilter == AttributeFilter.withValues,
                onSelected: () => onFilterChanged(AttributeFilter.withValues),
              ),
              const SizedBox(width: 6),
              _FilterChip(
                label: 'Sin valores',
                filter: AttributeFilter.withoutValues,
                isSelected: activeFilter == AttributeFilter.withoutValues,
                onSelected: () => onFilterChanged(AttributeFilter.withoutValues),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final AttributeFilter filter;
  final bool isSelected;
  final VoidCallback onSelected;

  const _FilterChip({
    required this.label,
    required this.filter,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
