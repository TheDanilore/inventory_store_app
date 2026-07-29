import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders/orders_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders/orders_state.dart';
import 'package:inventory_store_app/core/widgets/date_filter_calendar.dart';

class OrdersFiltersHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController searchCtrl;
  final Function(String) onSearchChanged;
  final OrdersCubit cubit;
  final OrdersState state;
  final Widget Function({
    required String label,
    required bool isSelected,
    required Function(bool) onSelected,
  })
  buildFilterChip;

  OrdersFiltersHeaderDelegate({
    required this.searchCtrl,
    required this.onSearchChanged,
    required this.cubit,
    required this.state,
    required this.buildFilterChip,
  });

  @override
  double get minExtent => 118.0;
  @override
  double get maxExtent => 118.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final bool isPaymentFiltered = state.paymentStatusFilter != 'ALL';

    return Container(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Buscador principal estilizado
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: SizedBox(
              height: 42,
              child: TextField(
                controller: searchCtrl,
                onChanged: onSearchChanged,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Buscar por cliente o ID de pedido...',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.teal,
                    size: 19,
                  ),
                  suffixIcon:
                      searchCtrl.text.isNotEmpty
                          ? IconButton(
                            icon: const Icon(
                              Icons.cancel_rounded,
                              color: Colors.grey,
                              size: 18,
                            ),
                            onPressed: () {
                              searchCtrl.clear();
                              cubit.setSearchQuery('');
                            },
                          )
                          : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.teal,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 0,
                  ),
                ),
              ),
            ),
          ),
          // Bar de Filtros Horizontales
          SizedBox(
            height: 42,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              children: [
                buildFilterChip(
                  label: 'Todos',
                  isSelected: state.statusFilter == 'ALL',
                  onSelected: (_) => cubit.setStatusFilter('ALL'),
                ),
                const SizedBox(width: 8),
                buildFilterChip(
                  label: 'Borradores',
                  isSelected: state.statusFilter == 'PENDING',
                  onSelected: (_) => cubit.setStatusFilter('PENDING'),
                ),
                const SizedBox(width: 8),
                buildFilterChip(
                  label: 'Completados',
                  isSelected: state.statusFilter == 'COMPLETED',
                  onSelected: (_) => cubit.setStatusFilter('COMPLETED'),
                ),
                const SizedBox(width: 8),
                buildFilterChip(
                  label: 'Cancelados',
                  isSelected: state.statusFilter == 'CANCELLED',
                  onSelected: (_) => cubit.setStatusFilter('CANCELLED'),
                ),
                const SizedBox(width: 8),
                buildFilterChip(
                  label: 'Devueltos',
                  isSelected: state.statusFilter == 'RETURNED',
                  onSelected: (_) => cubit.setStatusFilter('RETURNED'),
                ),
                const SizedBox(width: 12),
                // Dropdown estilizado de Cobros
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color:
                        isPaymentFiltered
                            ? AppColors.teal.withValues(alpha: 0.1)
                            : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          isPaymentFiltered
                              ? AppColors.teal
                              : Colors.grey.shade300,
                      width: isPaymentFiltered ? 1.5 : 1,
                    ),
                  ),
                  child: PopupMenuButton<String>(
                    initialValue: state.paymentStatusFilter,
                    offset: const Offset(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (val) {
                      cubit.setPaymentStatusFilter(val);
                    },
                    itemBuilder:
                        (context) => [
                          const PopupMenuItem(
                            value: 'ALL',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.payments_rounded,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Cobros: Todos',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'PAID',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 8),
                                Text('Pagados', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'PENDING',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.pending_actions_rounded,
                                  size: 16,
                                  color: Colors.orange,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Por cobrar',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'PARTIAL',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.pie_chart_rounded,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Parciales',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 14,
                            color:
                                isPaymentFiltered
                                    ? AppColors.teal
                                    : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getPaymentStatusLabel(state.paymentStatusFilter),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight:
                                  isPaymentFiltered
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                              color:
                                  isPaymentFiltered
                                      ? AppColors.teal
                                      : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color:
                                isPaymentFiltered
                                    ? AppColors.teal
                                    : AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DateFilterCalendar(
                  dateRange:
                      state.startDate != null && state.endDate != null
                          ? DateTimeRange(
                            start: state.startDate!,
                            end: state.endDate!,
                          )
                          : null,
                  onDateRangeSelected: (picked) {
                    cubit.setDateRange(picked.start, picked.end);
                  },
                  onClear: () {
                    cubit.setDateRange(null, null);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getPaymentStatusLabel(String status) {
    switch (status) {
      case 'PAID':
        return 'Pagados';
      case 'PENDING':
        return 'Por cobrar';
      case 'PARTIAL':
        return 'Parciales';
      default:
        return 'Cobros: Todos';
    }
  }

  @override
  bool shouldRebuild(covariant OrdersFiltersHeaderDelegate oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.searchCtrl.text != searchCtrl.text;
  }
}
