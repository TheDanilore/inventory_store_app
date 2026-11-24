import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credit_list_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credit_list_state.dart';

/// Barra de herramientas y filtros segmentados con conteo global desde SQL.
class CustomerCreditsToolbarSection extends StatelessWidget {
  final bool isDesktop;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueNotifier<int> tabIndexNotifier;
  final ValueNotifier<bool> isTableViewNotifier;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onRefresh;

  const CustomerCreditsToolbarSection({
    super.key,
    required this.isDesktop,
    required this.searchController,
    required this.searchFocusNode,
    required this.tabIndexNotifier,
    required this.isTableViewNotifier,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.onTabSelected,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      CustomerCreditListCubit,
      CustomerCreditListState,
      ({int debtCount, bool isRevalidating, bool hasData})
    >(
      selector:
          (state) => (
            debtCount: state.debtCount,
            isRevalidating: state.isRevalidating,
            hasData: state.hasData,
          ),
      builder: (context, vm) {
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
                        searchHint: 'Buscar por cliente, documento o teléfono...',
                        enableKeyboardShortcuts: false,
                        isLoading: vm.isRevalidating,
                        onSearchChanged: onSearchChanged,
                        onSearchSubmitted:
                            (q) => context
                                .read<CustomerCreditListCubit>()
                                .setSearch(q),
                        onClearSearch: onClearSearch,
                        filterWidgets: [
                          _SegmentedCreditFilter(
                            selectedIndex: tabIndex,
                            debtCount: vm.debtCount,
                            onTabSelected: onTabSelected,
                          ),
                        ],
                        filterGroups: [
                          AdminFilterGroup<int>(
                            title: 'Cuentas',
                            icon: Icons.account_balance_wallet_outlined,
                            selected: tabIndex,
                            defaultValue: 0,
                            onSelected: onTabSelected,
                            options: [
                              const AdminFilterOption(value: 0, label: 'Todas'),
                              AdminFilterOption(
                                value: 1,
                                label:
                                    vm.debtCount > 0
                                        ? 'Por cobrar (${vm.debtCount})'
                                        : 'Por cobrar',
                                color: AppColors.danger,
                              ),
                            ],
                          ),
                        ],
                        viewToggleConfig: AdminProViewToggleConfig(
                          isTableView: isTableView,
                          onToggleTableView:
                              (val) => isTableViewNotifier.value = val,
                        ),
                        onRefresh: onRefresh,
                        refreshTooltip: 'Refrescar créditos [R]',
                      );
                    },
                  ),
                  if (vm.isRevalidating && vm.hasData)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SegmentedCreditFilter extends StatelessWidget {
  final int selectedIndex;
  final int debtCount;
  final ValueChanged<int> onTabSelected;

  const _SegmentedCreditFilter({
    required this.selectedIndex,
    required this.debtCount,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _FilterTabButton(
              title: 'Todas',
              isSelected: selectedIndex == 0,
              onTap: () => onTabSelected(0),
            ),
            const SizedBox(width: 4),
            _FilterTabButton(
              title: 'Por Cobrar',
              count: debtCount,
              isSelected: selectedIndex == 1,
              onTap: () => onTabSelected(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterTabButton extends StatelessWidget {
  final String title;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTabButton({
    required this.title,
    this.count,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
              ),
            ),
            if (count != null && count! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.danger : AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.danger,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
