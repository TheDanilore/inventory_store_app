import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/orders_state.dart';
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
  double get minExtent => 140.0;
  @override
  double get maxExtent => 140.0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppColors.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              controller: searchCtrl,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Buscar por cliente o ID de pedido...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Colors.grey.shade400,
                ),
                suffixIcon:
                    searchCtrl.text.isNotEmpty
                        ? IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            color: Colors.grey,
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
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
              ),
            ),
          ),
          // Filtros
          SizedBox(
            height: 48,
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
                const SizedBox(width: 16),
                Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: PopupMenuButton<String>(
                    initialValue: state.paymentStatusFilter,
                    offset: const Offset(0, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (val) {
                      cubit.setPaymentStatusFilter(val);
                    },
                    itemBuilder:
                        (context) => const [
                          PopupMenuItem(
                            value: 'ALL',
                            child: Text('Cobros: Todos'),
                          ),
                          PopupMenuItem(value: 'PAID', child: Text('Pagados')),
                          PopupMenuItem(
                            value: 'PENDING',
                            child: Text('Por cobrar'),
                          ),
                          PopupMenuItem(
                            value: 'PARTIAL',
                            child: Text('Parciales'),
                          ),
                        ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getPaymentStatusLabel(state.paymentStatusFilter),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: Colors.black87,
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
