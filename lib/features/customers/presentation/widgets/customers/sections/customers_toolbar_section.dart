import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_state.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_state.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers/top_customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers/top_customers_state.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/common/top_vip_widgets.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/components/customers_segmented_filter.dart';

/// Barra de herramientas y filtros segmentados aislada con BlocSelectors granulares.
class CustomersToolbarSection extends StatelessWidget {
  final bool isDesktop;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueNotifier<int> tabIndexNotifier;
  final ValueNotifier<bool> isTableViewNotifier;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onRefresh;
  final VoidCallback onOpenTopCustomers;

  const CustomersToolbarSection({
    super.key,
    required this.isDesktop,
    required this.searchController,
    required this.searchFocusNode,
    required this.tabIndexNotifier,
    required this.isTableViewNotifier,
    required this.onTabSelected,
    required this.onRefresh,
    required this.onOpenTopCustomers,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      CustomersStatsCubit,
      CustomersStatsState,
      ({int totalCount, int debtCount})
    >(
      selector:
          (state) => (
            totalCount:
                state is CustomersStatsLoaded ? state.totalCustomersCount : 0,
            debtCount:
                state is CustomersStatsLoaded ? state.debtCustomersCount : 0,
          ),
      builder: (context, statsVm) {
        return BlocSelector<TopCustomersCubit, TopCustomersState, int>(
          selector:
              (state) =>
                  state is TopCustomersLoaded ? state.topCustomers.length : 0,
          builder: (context, topCount) {
            return BlocSelector<
              CustomersCubit,
              CustomersState,
              ({bool isRefreshing, bool hasCustomers, bool isExportingPdf})
            >(
              selector:
                  (state) => (
                    isRefreshing: state is CustomersLoaded && state.isRefreshing,
                    hasCustomers:
                        state is CustomersLoaded && state.hasCustomers,
                    isExportingPdf:
                        state is CustomersLoaded && state.isExportingPdf,
                  ),
              builder: (context, custVm) {
                return ValueListenableBuilder<int>(
                  valueListenable: tabIndexNotifier,
                  builder: (context, tabIndex, _) {
                    return SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ValueListenableBuilder<bool>(
                            valueListenable: isTableViewNotifier,
                            builder: (context, isTableView, _) {
                              return AdminProToolbar(
                                isDesktop: isDesktop,
                                searchController: searchController,
                                searchFocusNode: searchFocusNode,
                                searchHint:
                                    'Buscar por nombre, documento o teléfono...',
                                enableKeyboardShortcuts: false,
                                isLoading: custVm.isRefreshing,
                                onSearchChanged:
                                    (val) => context
                                        .read<CustomersCubit>()
                                        .search(val.trim()),
                                onSearchSubmitted:
                                    (val) => context
                                        .read<CustomersCubit>()
                                        .fetchCustomers(
                                          reset: true,
                                          query: val.trim(),
                                        ),
                                onClearSearch: () {
                                  searchController.clear();
                                  context.read<CustomersCubit>().search('');
                                },
                                filterWidgets: [
                                  CustomersSegmentedFilter(
                                    selectedIndex: tabIndex,
                                    totalCount: statsVm.totalCount,
                                    debtCount: statsVm.debtCount,
                                    topCount: topCount,
                                    onTabSelected: onTabSelected,
                                  ),
                                ],
                                filterGroups: [
                                  AdminFilterGroup<int>(
                                    title: 'Clientes',
                                    icon: Icons.people_alt_outlined,
                                    selected: tabIndex,
                                    defaultValue: 0,
                                    onSelected: onTabSelected,
                                    options: [
                                      AdminFilterOption(
                                        value: 0,
                                        label: 'Todos (${statsVm.totalCount})',
                                      ),
                                      AdminFilterOption(
                                        value: 1,
                                        label:
                                            statsVm.debtCount > 0
                                                ? 'Con deuda activa (${statsVm.debtCount})'
                                                : 'Con deuda activa',
                                        color: AppColors.danger,
                                      ),
                                      AdminFilterOption(
                                        value: 2,
                                        label: '👑 Top VIP ($topCount)',
                                        color: const Color(0xFFB45309),
                                      ),
                                    ],
                                  ),
                                ],
                                viewToggleConfig: AdminProViewToggleConfig(
                                  isTableView: isTableView,
                                  onToggleTableView:
                                      (val) =>
                                          isTableViewNotifier.value = val,
                                ),
                                onRefresh: onRefresh,
                                refreshTooltip: 'Recargar directorio [R]',
                                trailingActions: [
                                  Tooltip(
                                    message: 'Exportar a PDF',
                                    child: IconButton(
                                      icon:
                                          custVm.isExportingPdf
                                              ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                              : const Icon(
                                                Icons.picture_as_pdf_outlined,
                                                size: 19,
                                                color: AppColors.textSecondary,
                                              ),
                                      onPressed:
                                          custVm.isExportingPdf
                                              ? null
                                              : () =>
                                                  context
                                                      .read<CustomersCubit>()
                                                      .exportPdf(),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          if (custVm.isRefreshing && custVm.hasCustomers)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: ClipRRect(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(2),
                                ),
                                child: LinearProgressIndicator(
                                  minHeight: 2,
                                  backgroundColor: Colors.transparent,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.teal,
                                  ),
                                ),
                              ),
                            ),
                          if (tabIndex == 2)
                            TopVipBanner(onOpen: onOpenTopCustomers),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
