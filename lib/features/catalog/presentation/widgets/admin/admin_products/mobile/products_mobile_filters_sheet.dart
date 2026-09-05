import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';

/// Modal Bottom Sheet de filtros de catálogo para dispositivos móviles adaptado a Apple HIG.
class ProductsMobileFiltersSheet {
  static void show(BuildContext context, AdminCatalogCubit cubit) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
          builder: (context, currentState) {
            return Container(
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Apple Drag Handle
                      Center(
                        child: Container(
                          width: 36,
                          height: 5,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filtros de Catálogo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              cubit.setCategory(null);
                              cubit.setStockFilter(CatalogStockFilter.all);
                              cubit.setFilterIsActive(null);
                              if (currentState.searchByIngredient) {
                                cubit.toggleSearchByIngredient(false);
                              }
                              Navigator.pop(ctx);
                            },
                            child: const Text(
                              'Limpiar Todo',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Sección: Búsqueda por Principio Activo
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: currentState.searchByIngredient,
                        onChanged: (val) {
                          cubit.toggleSearchByIngredient(val);
                        },
                        title: const Text(
                          'Buscar por Principio Activo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        subtitle: const Text(
                          'Filtra por fórmula o componente farmacéutico',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        activeThumbColor: AppColors.accent,
                      ),
                      const Divider(color: AppColors.divider, height: 24),

                      // Sección: Disponibilidad de Stock
                      const Text(
                        'Disponibilidad de Stock',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Todos'),
                            selected:
                                currentState.stockFilter ==
                                CatalogStockFilter.all,
                            onSelected: (_) {
                              cubit.setStockFilter(CatalogStockFilter.all);
                            },
                          ),
                          ChoiceChip(
                            label: const Text('En Stock'),
                            selected:
                                currentState.stockFilter ==
                                CatalogStockFilter.inStock,
                            onSelected: (_) {
                              cubit.setStockFilter(CatalogStockFilter.inStock);
                            },
                          ),
                          ChoiceChip(
                            label: const Text('Agotados'),
                            selected:
                                currentState.stockFilter ==
                                CatalogStockFilter.outOfStock,
                            onSelected: (_) {
                              cubit.setStockFilter(
                                CatalogStockFilter.outOfStock,
                              );
                            },
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.divider, height: 24),

                      // Sección: Categoría
                      const Text(
                        'Categoría',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            ChoiceChip(
                              label: const Text('Todas'),
                              selected: currentState.selectedCategoryId == null,
                              onSelected: (_) => cubit.setCategory(null),
                            ),
                            const SizedBox(width: 8),
                            ...currentState.categories.map((cat) {
                              final isSelected =
                                  currentState.selectedCategoryId == cat.id;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(cat.name),
                                  selected: isSelected,
                                  onSelected:
                                      (_) => cubit.setCategory(
                                        isSelected ? null : cat.id,
                                      ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      const Divider(color: AppColors.divider, height: 24),

                      // Sección: Estado de Visibilidad
                      const Text(
                        'Estado de Visibilidad',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Todos'),
                            selected: currentState.filterIsActive == null,
                            onSelected: (_) => cubit.setFilterIsActive(null),
                          ),
                          ChoiceChip(
                            label: const Text('Activos'),
                            selected: currentState.filterIsActive == true,
                            onSelected: (_) => cubit.setFilterIsActive(true),
                          ),
                          ChoiceChip(
                            label: const Text('Inactivos'),
                            selected: currentState.filterIsActive == false,
                            onSelected: (_) => cubit.setFilterIsActive(false),
                          ),
                        ],
                      ),
                      const Divider(color: AppColors.divider, height: 24),

                      // Sección: Ordenar por
                      const Text(
                        'Ordenar por',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            CatalogSortOption.values.map((opt) {
                              return ChoiceChip(
                                label: Text(opt.label),
                                selected: currentState.sortOption == opt,
                                onSelected: (_) => cubit.setSortOption(opt),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Botón Aplicar Filtros
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppColors.radiusSm + 4,
                              ),
                            ),
                          ),
                          child: const Text(
                            'Aplicar Filtros',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
