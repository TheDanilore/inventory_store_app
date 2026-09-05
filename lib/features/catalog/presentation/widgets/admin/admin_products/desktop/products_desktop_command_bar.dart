import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/admin/admin_products/common/products_badges.dart';

/// Barra de comandos de escritorio estilo Stripe / Linear para catálogo de productos.
class ProductsDesktopCommandBar extends StatelessWidget {
  final AdminCatalogCubit cubit;
  final AdminCatalogState state;
  final TextEditingController searchCtrl;
  final FocusNode searchFocusNode;

  const ProductsDesktopCommandBar({
    super.key,
    required this.cubit,
    required this.state,
    required this.searchCtrl,
    required this.searchFocusNode,
  });

  int _countActiveFilters() {
    int count = 0;
    if (state.stockFilter != CatalogStockFilter.all) count++;
    if (state.selectedCategoryId != null) count++;
    if (state.filterIsActive != null) count++;
    if (state.searchByIngredient) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final activeFiltersCount = _countActiveFilters();
    final hasActiveFilters = activeFiltersCount > 0;

    final selectedCategory = state.categories.firstWhereOrNull(
      (c) => c.id == state.selectedCategoryId,
    );
    final selectedCategoryName = selectedCategory?.name ?? 'Categoría';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.radiusSm + 4),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nivel 1: Buscador + Principio Activo + Ordenamiento + Actualizar
          Row(
            children: [
              // Buscador compacto Pro
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TextField(
                    controller: searchCtrl,
                    focusNode: searchFocusNode,
                    onChanged: cubit.setSearchTerm,
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          state.searchByIngredient
                              ? 'Buscar por principio activo / fórmula farmacéutica...'
                              : 'Buscar por nombre, código o SKU...',
                      hintStyle: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (searchCtrl.text.isNotEmpty)
                            IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () {
                                searchCtrl.clear();
                                cubit.setSearchTerm('');
                              },
                              tooltip: 'Limpiar búsqueda',
                            ),
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.slateLight.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'Ctrl+K',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Chip Conmutador de Búsqueda por Principio Activo
              Tooltip(
                message:
                    'Conmutar para buscar por componente, fórmula o principio activo',
                child: FilterChip(
                  selected: state.searchByIngredient,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.science_outlined,
                        size: 15,
                        color:
                            state.searchByIngredient
                                ? AppColors.accent
                                : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Principio Activo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              state.searchByIngredient
                                  ? AppColors.accent
                                  : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  selectedColor: AppColors.accentLight.withValues(alpha: 0.2),
                  backgroundColor: AppColors.background,
                  side: BorderSide(
                    color:
                        state.searchByIngredient
                            ? AppColors.accent.withValues(alpha: 0.6)
                            : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  onSelected: (val) => cubit.toggleSearchByIngredient(val),
                ),
              ),
              const SizedBox(width: 10),

              // Selector de Ordenamiento
              PopupMenuButton<CatalogSortOption>(
                tooltip: 'Ordenar productos',
                initialValue: state.sortOption,
                onSelected: cubit.setSortOption,
                itemBuilder:
                    (context) =>
                        CatalogSortOption.values.map((opt) {
                          final isSelected = state.sortOption == opt;
                          return PopupMenuItem(
                            value: opt,
                            child: Row(
                              children: [
                                if (isSelected)
                                  const Icon(
                                    Icons.check_rounded,
                                    size: 16,
                                    color: AppColors.primary,
                                  )
                                else
                                  const SizedBox(width: 16),
                                const SizedBox(width: 8),
                                Text(
                                  opt.label,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.sort_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        state.sortOption.label,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Botón Actualizar
              OutlinedButton.icon(
                onPressed: () => cubit.refreshProducts(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Actualizar',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  backgroundColor: AppColors.background,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Nivel 2: Filtros Segmentados de Stock + Categorías + Estado + Limpiar
          Row(
            children: [
              // Chips Segmentados de Stock
              ProductSegmentChip(
                label: 'Todos',
                isSelected: state.stockFilter == CatalogStockFilter.all,
                onTap: () => cubit.setStockFilter(CatalogStockFilter.all),
              ),
              const SizedBox(width: 6),
              ProductSegmentChip(
                label: 'En Stock',
                icon: Icons.check_circle_outline_rounded,
                iconColor: AppColors.success,
                isSelected: state.stockFilter == CatalogStockFilter.inStock,
                onTap: () => cubit.setStockFilter(CatalogStockFilter.inStock),
              ),
              const SizedBox(width: 6),
              ProductSegmentChip(
                label: 'Agotados',
                icon: Icons.error_outline_rounded,
                iconColor: AppColors.danger,
                isSelected: state.stockFilter == CatalogStockFilter.outOfStock,
                onTap:
                    () => cubit.setStockFilter(CatalogStockFilter.outOfStock),
              ),

              const SizedBox(width: 14),
              Container(width: 1, height: 20, color: AppColors.border),
              const SizedBox(width: 14),

              // Filtro Dropdown de Categoría
              PopupMenuButton<String?>(
                tooltip: 'Filtrar por categoría',
                onSelected: cubit.setCategory,
                itemBuilder: (context) {
                  final items = <PopupMenuEntry<String?>>[
                    PopupMenuItem<String?>(
                      value: null,
                      child: Row(
                        children: [
                          if (state.selectedCategoryId == null)
                            const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: AppColors.primary,
                            )
                          else
                            const SizedBox(width: 16),
                          const SizedBox(width: 8),
                          const Text(
                            'Todas las categorías',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                  ];
                  for (final cat in state.categories) {
                    final isCatSelected = state.selectedCategoryId == cat.id;
                    items.add(
                      PopupMenuItem<String?>(
                        value: cat.id,
                        child: Row(
                          children: [
                            if (isCatSelected)
                              const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: AppColors.primary,
                              )
                            else
                              const SizedBox(width: 16),
                            const SizedBox(width: 8),
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight:
                                    isCatSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return items;
                },
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color:
                        state.selectedCategoryId != null
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : AppColors.background,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(
                      color:
                          state.selectedCategoryId != null
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 14,
                        color:
                            state.selectedCategoryId != null
                                ? AppColors.primary
                                : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        selectedCategoryName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              state.selectedCategoryId != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color:
                            state.selectedCategoryId != null
                                ? AppColors.primary
                                : AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Filtro Dropdown de Estado (Activo / Inactivo)
              PopupMenuButton<bool?>(
                tooltip: 'Filtrar por estado',
                onSelected: cubit.setFilterIsActive,
                itemBuilder:
                    (context) => [
                      PopupMenuItem(
                        value: null,
                        child: Row(
                          children: [
                            if (state.filterIsActive == null)
                              const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: AppColors.primary,
                              )
                            else
                              const SizedBox(width: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'Todos los estados',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: true,
                        child: Row(
                          children: [
                            if (state.filterIsActive == true)
                              const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: AppColors.primary,
                              )
                            else
                              const SizedBox(width: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'Solo Activos',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: false,
                        child: Row(
                          children: [
                            if (state.filterIsActive == false)
                              const Icon(
                                Icons.check_rounded,
                                size: 16,
                                color: AppColors.primary,
                              )
                            else
                              const SizedBox(width: 16),
                            const SizedBox(width: 8),
                            const Text(
                              'Solo Inactivos',
                              style: TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color:
                        state.filterIsActive != null
                            ? AppColors.primary.withValues(alpha: 0.08)
                            : AppColors.background,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(
                      color:
                          state.filterIsActive != null
                              ? AppColors.primary.withValues(alpha: 0.3)
                              : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 14,
                        color:
                            state.filterIsActive != null
                                ? AppColors.primary
                                : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        state.filterIsActive == null
                            ? 'Estado'
                            : (state.filterIsActive! ? 'Activos' : 'Inactivos'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              state.filterIsActive != null
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 14,
                        color:
                            state.filterIsActive != null
                                ? AppColors.primary
                                : AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),

              if (hasActiveFilters) ...[
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: () {
                    cubit.setCategory(null);
                    cubit.setStockFilter(CatalogStockFilter.all);
                    cubit.setFilterIsActive(null);
                    if (state.searchByIngredient) {
                      cubit.toggleSearchByIngredient(false);
                    }
                  },
                  icon: const Icon(
                    Icons.clear_all_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  label: const Text(
                    'Limpiar filtros',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],

              const Spacer(),

              // Contador de productos
              Text(
                '${state.totalCount} ${state.totalCount == 1 ? "producto" : "productos"}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
