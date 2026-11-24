import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_pro_toolbar.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_state.dart';

class SuppliersToolbarSection extends StatelessWidget {
  final bool isDesktop;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final ValueNotifier<bool> isTableViewNotifier;

  const SuppliersToolbarSection({
    super.key,
    required this.isDesktop,
    required this.searchController,
    required this.searchFocusNode,
    required this.isTableViewNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      SuppliersCubit,
      SuppliersState,
      ({bool? filterIsActive, bool isRevalidating, bool hasData})
    >(
      selector:
          (state) => (
            filterIsActive: state.filterIsActive,
            isRevalidating: state.isRevalidating,
            hasData: state.hasData,
          ),
      builder: (context, vm) {
        final cubit = context.read<SuppliersCubit>();

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
                  searchHint: 'Buscar por nombre, RUC o contacto...',
                  enableKeyboardShortcuts: false,
                  isLoading: vm.isRevalidating,
                  onSearchChanged: cubit.setSearchQueryDebounced,
                  onSearchSubmitted: cubit.setSearchQuery,
                  onClearSearch: () {
                    searchController.clear();
                    cubit.setSearchQuery('');
                  },
                  filterGroups: [
                    AdminFilterGroup<bool?>(
                      title: 'Estado',
                      icon: Icons.toggle_on_outlined,
                      selected: vm.filterIsActive,
                      defaultValue: null,
                      onSelected: cubit.setFilterIsActive,
                      options: const [
                        AdminFilterOption<bool?>(
                          value: null,
                          label: 'Todos',
                        ),
                        AdminFilterOption<bool?>(
                          value: true,
                          label: 'Activos',
                          icon: Icons.check_circle_rounded,
                          color: AppColors.successDark,
                        ),
                        AdminFilterOption<bool?>(
                          value: false,
                          label: 'Inactivos',
                          icon: Icons.pause_circle_rounded,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                  viewToggleConfig: AdminProViewToggleConfig(
                    isTableView: isTableView,
                    onToggleTableView:
                        (val) => isTableViewNotifier.value = val,
                  ),
                  onRefresh: () => cubit.loadSuppliers(forceRefresh: true),
                  refreshTooltip: 'Refrescar proveedores [R]',
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
