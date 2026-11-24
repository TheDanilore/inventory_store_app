import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credit_list_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credit_list_state.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/credit_account_card.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/customer_credits_table.dart';

/// Sección sliver de contenido: soporta Zero-Shimmer, ErrorCold, ErrorDegraded,
/// Skeleton de 1 único AnimationController y vistas Tabla / Grid / Lista móvil.
class CustomerCreditsContentSection extends StatelessWidget {
  final bool isWide;
  final ValueNotifier<bool> isTableViewNotifier;
  final ValueChanged<CustomerCreditEntity> onPayTap;
  final ValueChanged<CustomerCreditEntity> onHistoryTap;
  final ValueChanged<CustomerCreditEntity> onEditTap;
  final ValueChanged<CustomerCreditEntity> onToggleStatusTap;
  final ValueChanged<CustomerCreditEntity> onShowAccountOptions;
  final void Function(String text, String label) onCopy;
  final VoidCallback onCreateAccount;
  final VoidCallback onClearSearch;
  final VoidCallback onRetry;

  const CustomerCreditsContentSection({
    super.key,
    required this.isWide,
    required this.isTableViewNotifier,
    required this.onPayTap,
    required this.onHistoryTap,
    required this.onEditTap,
    required this.onToggleStatusTap,
    required this.onShowAccountOptions,
    required this.onCopy,
    required this.onCreateAccount,
    required this.onClearSearch,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      CustomerCreditListCubit,
      CustomerCreditListState,
      ({
        CustomerCreditsLoadStatus status,
        bool isColdLoading,
        List<CustomerCreditEntity> accounts,
        Failure? loadFailure,
        String? transientErrorMessage,
        String searchQuery,
        bool withDebtOnly,
      })
    >(
      selector:
          (state) => (
            status: state.status,
            isColdLoading: state.isColdLoading,
            accounts: state.accounts,
            loadFailure: state.loadFailure,
            transientErrorMessage: state.transientErrorMessage,
            searchQuery: state.searchQuery,
            withDebtOnly: state.withDebtOnly,
          ),
      builder: (context, vm) {
        return ValueListenableBuilder<bool>(
          valueListenable: isTableViewNotifier,
          builder: (context, isTableView, _) {
            if (vm.isColdLoading ||
                (vm.status == CustomerCreditsLoadStatus.initial &&
                    vm.accounts.isEmpty)) {
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: _SingleTickerCreditsSkeleton(
                    isTableView: isWide && isTableView,
                    isWide: isWide,
                  ),
                ),
              );
            }

            if (vm.status == CustomerCreditsLoadStatus.errorCold &&
                vm.accounts.isEmpty) {
              final failure = vm.loadFailure;
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
                          : (isUnauth
                              ? 'Acceso restringido'
                              : 'Error al cargar créditos'),
                  message:
                      failure?.message ??
                      'No pudimos obtener las líneas de crédito.',
                  action: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ),
              );
            }

            if (vm.accounts.isEmpty) {
              final hasSearch = vm.searchQuery.isNotEmpty;
              return SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: Icons.receipt_long_rounded,
                  title:
                      hasSearch
                          ? 'No se encontraron resultados'
                          : (vm.withDebtOnly
                              ? 'No hay créditos con deuda pendiente'
                              : 'No hay líneas de crédito registradas'),
                  message:
                      hasSearch
                          ? 'No hay resultados que coincidan con "${vm.searchQuery}".'
                          : 'Crea una nueva línea de crédito para autorizar ventas a plazo.',
                  action: FilledButton(
                    onPressed: hasSearch ? onClearSearch : onCreateAccount,
                    child: Text(
                      hasSearch
                          ? 'Limpiar filtro'
                          : '+ Nueva Línea de Crédito',
                    ),
                  ),
                ),
              );
            }

            final Widget contentSliver;
            if (isWide && isTableView) {
              contentSliver = SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverToBoxAdapter(
                  child: CustomerCreditsTable(
                    accounts: vm.accounts,
                    onPayTap: onPayTap,
                    onHistoryTap: onHistoryTap,
                    onEditTap: onEditTap,
                    onToggleStatusTap: onToggleStatusTap,
                    onCopy: onCopy,
                  ),
                ),
              );
            } else if (isWide) {
              contentSliver = SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 420,
                    mainAxisExtent: 220,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final account = vm.accounts[index];
                      return CreditAccountCard(
                        key: ValueKey('cc_grid_${account.id}'),
                        account: account,
                        onTap: () => onShowAccountOptions(account),
                        onPayTap:
                            account.isActive && account.currentDebt > 0
                                ? () => onPayTap(account)
                                : null,
                        onHistoryTap: () => onHistoryTap(account),
                      );
                    },
                    childCount: vm.accounts.length,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                  ),
                ),
              );
            } else {
              contentSliver = SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final account = vm.accounts[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CreditAccountCard(
                          key: ValueKey('cc_list_${account.id}'),
                          account: account,
                          onTap: () => onShowAccountOptions(account),
                          onPayTap:
                              account.isActive && account.currentDebt > 0
                                  ? () => onPayTap(account)
                                  : null,
                          onHistoryTap: () => onHistoryTap(account),
                        ),
                      );
                    },
                    childCount: vm.accounts.length,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                  ),
                ),
              );
            }

            if (vm.transientErrorMessage == null) {
              return contentSliver;
            }

            return SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: _DegradedBanner(
                    message: vm.transientErrorMessage!,
                    onRetry: onRetry,
                    onDismiss:
                        () =>
                            context
                                .read<CustomerCreditListCubit>()
                                .dismissTransientError(),
                  ),
                ),
                contentSliver,
              ],
            );
          },
        );
      },
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
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
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
              'Mostrando líneas en caché · $message',
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

class _SingleTickerCreditsSkeleton extends StatefulWidget {
  final bool isTableView;
  final bool isWide;

  const _SingleTickerCreditsSkeleton({
    required this.isTableView,
    required this.isWide,
  });

  @override
  State<_SingleTickerCreditsSkeleton> createState() =>
      _SingleTickerCreditsSkeletonState();
}

class _SingleTickerCreditsSkeletonState
    extends State<_SingleTickerCreditsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final color =
            Color.lerp(
              const Color(0xFFE2E8F0),
              const Color(0xFFF1F5F9),
              _controller.value,
            )!;

        if (widget.isTableView) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: List.generate(
                6,
                (i) => Container(
                  height: 44,
                  margin: EdgeInsets.only(bottom: i == 5 ? 0 : 10),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          );
        }

        if (widget.isWide) {
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 420,
              mainAxisExtent: 220,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: 6,
            itemBuilder:
                (_, _) => DecoratedBox(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
          );
        }

        return Column(
          children: List.generate(
            4,
            (i) => Container(
              height: 180,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        );
      },
    );
  }
}
