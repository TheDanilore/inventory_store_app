import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_state.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_credits_segmented_filter.dart';

class SupplierCreditsToolbarSection extends StatelessWidget {
  final bool isDesktop;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueNotifier<bool> isTableViewNotifier;
  final ValueChanged<int> onSelectTab;

  const SupplierCreditsToolbarSection({
    super.key,
    required this.isDesktop,
    required this.searchController,
    required this.searchFocusNode,
    required this.isTableViewNotifier,
    required this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      SupplierCreditsCubit,
      SupplierCreditsState,
      ({int debtCount, bool withDebtOnly, bool isRevalidating, bool hasData})
    >(
      selector:
          (state) => (
            debtCount: state.stats.debtCount,
            withDebtOnly: state.withDebtOnly,
            isRevalidating: state.isRevalidating,
            hasData: state.hasData,
          ),
      builder: (context, vm) {
        final cubit = context.read<SupplierCreditsCubit>();
        final tabIndex = vm.withDebtOnly ? 1 : 0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: isTableViewNotifier,
              builder: (context, isTableView, _) {
                return AdminProToolbar(
                  isDesktop: isDesktop,
                  searchController: searchController,
                  searchFocusNode: searchFocusNode,
                  searchHint: 'Buscar por proveedor o RUC...',
                  enableKeyboardShortcuts: false,
                  isLoading: vm.isRevalidating,
                  onSearchChanged: cubit.setSearchQuery,
                  onSearchSubmitted: cubit.setSearchQuery,
                  onClearSearch: () {
                    searchController.clear();
                    cubit.setSearchQuery('');
                  },
                  filterWidgets: [
                    SupplierCreditsSegmentedFilter(
                      selectedIndex: tabIndex,
                      debtCount: vm.debtCount,
                      onSelectTab: onSelectTab,
                    ),
                  ],
                  filterGroups: [
                    AdminFilterGroup<int>(
                      title: 'Cuentas',
                      icon: Icons.account_balance_wallet_outlined,
                      selected: tabIndex,
                      defaultValue: 0,
                      onSelected: onSelectTab,
                      options: [
                        const AdminFilterOption(value: 0, label: 'Todas'),
                        AdminFilterOption(
                          value: 1,
                          label:
                              vm.debtCount > 0
                                  ? 'Por pagar (${vm.debtCount})'
                                  : 'Por pagar',
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
                  onRefresh: () => cubit.loadAccounts(forceRefresh: true),
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
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.teal),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
