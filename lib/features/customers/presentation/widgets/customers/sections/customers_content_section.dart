import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_state.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers/top_customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers/top_customers_state.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/components/customers_empty_state.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/customer_list_card.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/customers_table_view.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/skeletons/customers_skeletons.dart';

/// Sección sliver principal del listado de clientes (Tabla Desktop / Grid / Lista Móvil).
class CustomersContentSection extends StatelessWidget {
  final bool isMobile;
  final ValueNotifier<int> tabIndexNotifier;
  final ValueNotifier<bool> isTableViewNotifier;
  final ValueNotifier<String?> selectedCustomerIdNotifier;
  final TextEditingController searchController;
  final VoidCallback onCreateCustomer;
  final VoidCallback onReload;
  final ValueChanged<CustomerEntity> onOpenDetail;
  final ValueChanged<CustomerEntity> onEditCustomer;
  final ValueChanged<String> onWhatsApp;
  final ValueChanged<CustomerEntity> onDesktopInspector;
  final ValueChanged<CustomerEntity> onMobileActionSheet;
  final void Function(BuildContext, Offset, CustomerEntity) onContextMenu;

  const CustomersContentSection({
    super.key,
    required this.isMobile,
    required this.tabIndexNotifier,
    required this.isTableViewNotifier,
    required this.selectedCustomerIdNotifier,
    required this.searchController,
    required this.onCreateCustomer,
    required this.onReload,
    required this.onOpenDetail,
    required this.onEditCustomer,
    required this.onWhatsApp,
    required this.onDesktopInspector,
    required this.onMobileActionSheet,
    required this.onContextMenu,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      TopCustomersCubit,
      TopCustomersState,
      List<CustomerEntity>
    >(
      selector:
          (state) =>
              state is TopCustomersLoaded ? state.topCustomers : const [],
      builder: (context, topList) {
        return BlocBuilder<CustomersCubit, CustomersState>(
          builder: (context, state) {
            return ValueListenableBuilder<bool>(
              valueListenable: isTableViewNotifier,
              builder: (context, isTableView, _) {
                return ValueListenableBuilder<int>(
                  valueListenable: tabIndexNotifier,
                  builder: (context, tabIndex, _) {
                    if (state is CustomersLoading ||
                        state is CustomersInitial) {
                      return (isMobile || !isTableView)
                          ? const CustomersCardSkeleton()
                          : const DesktopTableSkeleton();
                    }

                    if (state is CustomersError) {
                      return _buildErrorSliver(state.failure);
                    }

                    if (state is CustomersLoaded) {
                      final List<CustomerEntity> displayList =
                          tabIndex == 2 && topList.isNotEmpty
                              ? topList
                              : state.customers;

                      if (displayList.isEmpty) {
                        return SliverFillRemaining(
                          hasScrollBody: false,
                          child: CustomersEmptyState(
                            tabIndex: tabIndex,
                            searchQuery: searchController.text,
                            onCreateCustomer: onCreateCustomer,
                          ),
                        );
                      }

                      final bool hidePagination = tabIndex == 2;
                      final Widget bodySliver = _buildBodySliver(
                        context: context,
                        displayList: displayList,
                        topList: topList,
                        state: state,
                        isTableView: isTableView,
                        hidePagination: hidePagination,
                      );

                      if (state.transientErrorMessage == null) {
                        return bodySliver;
                      }

                      return SliverMainAxisGroup(
                        slivers: [
                          SliverToBoxAdapter(
                            child: _DegradedBanner(
                              message: state.transientErrorMessage!,
                              onRetry: onReload,
                              onDismiss:
                                  () =>
                                      context
                                          .read<CustomersCubit>()
                                          .dismissTransientError(),
                            ),
                          ),
                          bodySliver,
                        ],
                      );
                    }

                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildBodySliver({
    required BuildContext context,
    required List<CustomerEntity> displayList,
    required List<CustomerEntity> topList,
    required CustomersLoaded state,
    required bool isTableView,
    required bool hidePagination,
  }) {
    final bool showFooter = !hidePagination;

    if (isMobile) {
      final int extraItem = showFooter ? 1 : 0;
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (showFooter && index == displayList.length) {
                return _LoadMoreFooter(
                  hasReachedMax: state.hasReachedMax,
                  isLoadingMore: state.isLoadingMore,
                  onLoadMore:
                      () => context.read<CustomersCubit>().fetchCustomers(),
                );
              }
              final c = displayList[index];
              return CustomerListCard(
                key: ValueKey('cust_card_${c.id}'),
                customer: c,
                onTap: () => onMobileActionSheet(c),
              );
            },
            childCount: displayList.length + extraItem,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: true,
          ),
        ),
      );
    }

    if (!isTableView) {
      return SliverMainAxisGroup(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 440,
                mainAxisExtent: 180,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final c = displayList[index];
                  return CustomerListCard(
                    key: ValueKey('cust_grid_${c.id}'),
                    customer: c,
                    onTap: () => onDesktopInspector(c),
                  );
                },
                childCount: displayList.length,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
              ),
            ),
          ),
          if (showFooter)
            SliverToBoxAdapter(
              child: _LoadMoreFooter(
                hasReachedMax: state.hasReachedMax,
                isLoadingMore: state.isLoadingMore,
                onLoadMore:
                    () => context.read<CustomersCubit>().fetchCustomers(),
              ),
            ),
        ],
      );
    }

    return ValueListenableBuilder<String?>(
      valueListenable: selectedCustomerIdNotifier,
      builder: (context, selectedId, _) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: CustomersTableView(
              customers: displayList,
              topVipList: topList,
              selectedCustomerId: selectedId,
              initialSortColumn: hidePagination ? 'revenue' : null,
              initialSortAscending: !hidePagination,
              hasReachedMax: hidePagination ? true : state.hasReachedMax,
              isLoadingMore: state.isLoadingMore,
              onRowTap: onDesktopInspector,
              onOpenDetail: onOpenDetail,
              onEditCustomer: onEditCustomer,
              onWhatsApp: onWhatsApp,
              onContextMenu: onContextMenu,
              onLoadMore: () => context.read<CustomersCubit>().fetchCustomers(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorSliver(Failure failure) {
    final isNetwork = failure is NetworkFailure;
    final isUnauth = failure is UnauthorizedFailure;

    return SliverFillRemaining(
      hasScrollBody: false,
      child: AppEmptyState(
        icon:
            isNetwork
                ? Icons.wifi_off_rounded
                : (isUnauth
                    ? Icons.lock_outline_rounded
                    : Icons.error_outline_rounded),
        color: AppColors.danger,
        title:
            isNetwork
                ? 'Sin conexión a internet'
                : (isUnauth ? 'Acceso restringido' : 'Error al cargar clientes'),
        message: failure.message,
        action: ElevatedButton.icon(
          onPressed: onReload,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reintentar'),
        ),
      ),
    );
  }
}

class _DegradedBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const _DegradedBanner({
    required this.message,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 16,
            color: AppColors.warningDark,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Mostrando datos en caché · $message',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.warningDark,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: AppColors.warningDark,
            ),
            child: const Text(
              'Reintentar',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            visualDensity: VisualDensity.compact,
            color: AppColors.warningDark,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _LoadMoreFooter extends StatelessWidget {
  final bool hasReachedMax;
  final bool isLoadingMore;
  final VoidCallback onLoadMore;

  const _LoadMoreFooter({
    required this.hasReachedMax,
    required this.isLoadingMore,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    if (hasReachedMax) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Fin del catálogo de clientes',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      );
    }
    if (isLoadingMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: OutlinedButton.icon(
          onPressed: onLoadMore,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          label: const Text('Cargar más clientes'),
        ),
      ),
    );
  }
}
