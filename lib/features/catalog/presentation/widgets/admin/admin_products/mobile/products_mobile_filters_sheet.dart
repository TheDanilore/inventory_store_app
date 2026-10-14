import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/enums/catalog_enums.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_state.dart';

/// Filtros del catálogo para móvil.
///
/// IMPORTANTE: se abre con el navigator raíz, que NO hereda los providers de
/// la pantalla. Por eso se re-inyecta el cubit con BlocProvider.value; sin
/// eso, cualquier BlocBuilder/context.read dentro del sheet lanza excepción
/// y el modal queda vacío (solo se ve la barrera gris).
class ProductsMobileFiltersSheet {
  static Future<void> show(BuildContext context, AdminCatalogCubit cubit) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => BlocProvider.value(
            value: cubit,
            child: const _FiltersContent(),
          ),
    );
  }
}

class _FiltersContent extends StatelessWidget {
  const _FiltersContent();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AdminCatalogCubit>();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: BlocBuilder<AdminCatalogCubit, AdminCatalogState>(
        builder: (context, state) {
          final activeCount = _activeCount(state);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Filtros',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (activeCount > 0)
                      TextButton(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          cubit.setCategory(null);
                          cubit.setStockFilter(CatalogStockFilter.all);
                          cubit.setFilterIsActive(null);
                          cubit.setSortOption(CatalogSortOption.recent);
                          if (state.searchByIngredient) {
                            cubit.toggleSearchByIngredient(false);
                          }
                        },
                        child: const Text('Limpiar'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Group(
                        title: 'Estado',
                        child: _Chips<bool?>(
                          selected: state.filterIsActive,
                          onSelected: cubit.setFilterIsActive,
                          options: const [
                            (null, 'Todos'),
                            (true, 'Activos'),
                            (false, 'Inactivos'),
                          ],
                        ),
                      ),
                      _Group(
                        title: 'Stock',
                        child: _Chips<CatalogStockFilter>(
                          selected: state.stockFilter,
                          onSelected: (v) => cubit.setStockFilter(v!),
                          options: const [
                            (CatalogStockFilter.all, 'Todos'),
                            (CatalogStockFilter.inStock, 'En stock'),
                            (CatalogStockFilter.outOfStock, 'Agotados'),
                          ],
                        ),
                      ),
                      _Group(
                        title: 'Categoría',
                        child: _Chips<String?>(
                          selected: state.selectedCategoryId,
                          onSelected: cubit.setCategory,
                          options: [
                            (null, 'Todas'),
                            for (final c in state.categories) (c.id, c.name),
                          ],
                        ),
                      ),
                      _Group(
                        title: 'Ordenar por',
                        child: _Chips<CatalogSortOption>(
                          selected: state.sortOption,
                          onSelected: (v) => cubit.setSortOption(v!),
                          options: [
                            for (final o in CatalogSortOption.values)
                              (o, o.label),
                          ],
                        ),
                      ),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: state.searchByIngredient,
                        onChanged: cubit.toggleSearchByIngredient,
                        title: const Text(
                          'Buscar por principio activo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Busca por fórmula en lugar de nombre/SKU',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  12 + MediaQuery.paddingOf(context).bottom,
                ),
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Ver ${state.totalCount} productos',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static int _activeCount(AdminCatalogState s) {
    var n = 0;
    if (s.stockFilter != CatalogStockFilter.all) n++;
    if (s.selectedCategoryId != null) n++;
    if (s.filterIsActive != null) n++;
    if (s.sortOption != CatalogSortOption.recent) n++;
    if (s.searchByIngredient) n++;
    return n;
  }
}

class _Group extends StatelessWidget {
  final String title;
  final Widget child;
  const _Group({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    ),
  );
}

class _Chips<T> extends StatelessWidget {
  final T selected;
  final ValueChanged<T?> onSelected;
  final List<(T, String)> options;

  const _Chips({
    required this.selected,
    required this.onSelected,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in options)
          ChoiceChip(
            label: Text(label),
            selected: selected == value,
            showCheckmark: false,
            onSelected: (_) {
              HapticFeedback.selectionClick();
              onSelected(value);
            },
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color:
                  selected == value ? Colors.white : AppColors.textPrimary,
            ),
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.background,
            side: BorderSide(
              color:
                  selected == value ? AppColors.primary : AppColors.border,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
      ],
    );
  }
}