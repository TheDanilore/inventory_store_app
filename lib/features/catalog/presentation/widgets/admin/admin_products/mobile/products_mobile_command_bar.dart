import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';

/// Barra de comandos compacta para móvil inspirada en Apple HIG.
class ProductsMobileCommandBar extends StatelessWidget {
  final AdminCatalogCubit cubit;
  final AdminCatalogState state;
  final TextEditingController searchCtrl;
  final FocusNode searchFocusNode;
  final VoidCallback onOpenFilters;

  const ProductsMobileCommandBar({
    super.key,
    required this.cubit,
    required this.state,
    required this.searchCtrl,
    required this.searchFocusNode,
    required this.onOpenFilters,
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

    return Row(
      children: [
        // Buscador expandible
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppColors.radius),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: searchCtrl,
              focusNode: searchFocusNode,
              onChanged: cubit.setSearchTerm,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText:
                    state.searchByIngredient
                        ? 'Buscar por componente...'
                        : 'Buscar producto o código...',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                  size: 20,
                ),
                suffixIcon:
                    searchCtrl.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () {
                            searchCtrl.clear();
                            cubit.setSearchTerm('');
                          },
                        )
                        : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Botón de Filtros con Badge semántico
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color:
                    hasActiveFilters
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.surface,
                borderRadius: BorderRadius.circular(AppColors.radius),
                border: Border.all(
                  color: hasActiveFilters ? AppColors.primary : AppColors.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: onOpenFilters,
                icon: Icon(
                  Icons.tune_rounded,
                  size: 20,
                  color:
                      hasActiveFilters
                          ? AppColors.primary
                          : AppColors.textSecondary,
                ),
                tooltip: 'Filtros de Catálogo',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                padding: const EdgeInsets.all(10),
              ),
            ),
            if (hasActiveFilters)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$activeFiltersCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),

        // Botón Actualizar
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.radius),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () => cubit.refreshProducts(),
            icon: const Icon(
              Icons.refresh_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
            tooltip: 'Actualizar',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            padding: const EdgeInsets.all(10),
          ),
        ),
      ],
    );
  }
}
