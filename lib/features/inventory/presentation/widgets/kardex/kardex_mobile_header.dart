import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex/kardex_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/kardex/kardex_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_search_input.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/kardex/kardex_type_filter_row.dart';

/// Delegate para mantener el header sticky en scroll en móvil / tablet.
class KardexMobileHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  KardexMobileHeaderDelegate({required this.child});

  @override
  double get minExtent => 98.0;
  @override
  double get maxExtent => 98.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(KardexMobileHeaderDelegate oldDelegate) => true;
}

/// Cabecera sticky de controles de búsqueda y filtros para dispositivos móviles.
class KardexMobileHeader extends StatelessWidget {
  final TextEditingController searchCtrl;
  final FocusNode searchFocusNode;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final VoidCallback onClearSearch;

  const KardexMobileHeader({
    super.key,
    required this.searchCtrl,
    required this.searchFocusNode,
    required this.onSearchChanged,
    this.onSearchSubmitted,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: BlocSelector<KardexCubit, KardexState, bool>(
                  selector:
                      (state) => state is KardexLoaded && state.isSearching,
                  builder: (context, isSearching) {
                    return KardexSearchInput(
                      controller: searchCtrl,
                      focusNode: searchFocusNode,
                      hint: 'Buscar en kárdex...',
                      isLoading: isSearching,
                      onChanged: onSearchChanged,
                      onSubmitted: onSearchSubmitted,
                      onClear: onClearSearch,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Selector de Fecha
              BlocSelector<
                KardexCubit,
                KardexState,
                ({DateTime? startDate, DateTime? endDate})
              >(
                selector:
                    (state) => (
                      startDate: state is KardexLoaded ? state.startDate : null,
                      endDate: state is KardexLoaded ? state.endDate : null,
                    ),
                builder: (context, dates) {
                  final cubit = context.read<KardexCubit>();
                  return DateFilterCalendar(
                    dateRange:
                        dates.startDate != null && dates.endDate != null
                            ? DateTimeRange(
                              start: dates.startDate!,
                              end: dates.endDate!,
                            )
                            : null,
                    onDateRangeSelected: (picked) {
                      cubit.setDateRange(picked.start, picked.end);
                    },
                    onClear: () {
                      cubit.setDateRange(null, null);
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Píldoras horizontales de Tipo de Operación
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: BlocSelector<KardexCubit, KardexState, String>(
              selector:
                  (state) => state is KardexLoaded ? state.typeFilter : 'ALL',
              builder: (context, typeFilter) {
                final cubit = context.read<KardexCubit>();
                return Row(
                  children: [
                    KardexFilterPill(
                      label: 'Todos',
                      isSelected: typeFilter == 'ALL',
                      onTap: () => cubit.setTypeFilter('ALL'),
                    ),
                    const SizedBox(width: 6),
                    KardexFilterPill(
                      label: 'Ingresos',
                      isSelected: typeFilter == 'ENTRY',
                      onTap: () => cubit.setTypeFilter('ENTRY'),
                    ),
                    const SizedBox(width: 6),
                    KardexFilterPill(
                      label: 'Salidas',
                      isSelected: typeFilter == 'EXIT',
                      onTap: () => cubit.setTypeFilter('EXIT'),
                    ),
                    const SizedBox(width: 6),
                    KardexFilterPill(
                      label: 'Ventas',
                      isSelected: typeFilter == 'SALE',
                      onTap: () => cubit.setTypeFilter('SALE'),
                    ),
                    const SizedBox(width: 6),
                    KardexFilterPill(
                      label: 'Devoluciones',
                      isSelected: typeFilter == 'RETURN',
                      onTap: () => cubit.setTypeFilter('RETURN'),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
