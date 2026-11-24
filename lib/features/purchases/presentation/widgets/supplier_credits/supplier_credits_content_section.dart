import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_state.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_credit_card.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_credits_table.dart';

class SupplierCreditsContentSection extends StatelessWidget {
  final bool isWide;
  final ValueNotifier<bool> isTableViewNotifier;
  final ValueNotifier<String?> selectedCreditIdNotifier;
  final ValueChanged<SupplierCreditEntity> onAccountSelected;
  final ValueChanged<SupplierCreditEntity> onPay;
  final ValueChanged<SupplierCreditEntity> onViewHistory;
  final VoidCallback onCreateAccount;
  final VoidCallback onClearFilters;

  const SupplierCreditsContentSection({
    super.key,
    required this.isWide,
    required this.isTableViewNotifier,
    required this.selectedCreditIdNotifier,
    required this.onAccountSelected,
    required this.onPay,
    required this.onViewHistory,
    required this.onCreateAccount,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      SupplierCreditsCubit,
      SupplierCreditsState,
      ({
        SupplierCreditsLoadStatus status,
        bool isColdLoading,
        List<SupplierCreditEntity> accounts,
        Failure? loadFailure,
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
            searchQuery: state.searchQuery,
            withDebtOnly: state.withDebtOnly,
          ),
      builder: (context, vm) {
        final cubit = context.read<SupplierCreditsCubit>();

        return ValueListenableBuilder<bool>(
          valueListenable: isTableViewNotifier,
          builder: (context, isTableView, _) {
            // 1. Cold-Start Skeleton (Solo cuando NO hay datos en caché ni previos)
            if (vm.isColdLoading) {
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

            // 2. Error Cold (Sin datos en memoria)
            if (vm.status == SupplierCreditsLoadStatus.error &&
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
                          : (isUnauth ? 'Acceso restringido' : 'Ocurrió un error'),
                  message:
                      failure?.message ??
                      'No pudimos cargar las cuentas de crédito.',
                  action: ElevatedButton.icon(
                    onPressed: () => cubit.loadAccounts(forceRefresh: true),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ),
              );
            }

            // 3. Empty vs EmptyFiltered
            if (vm.accounts.isEmpty) {
              final hasFilters =
                  vm.searchQuery.isNotEmpty || vm.withDebtOnly;
              return SliverFillRemaining(
                hasScrollBody: false,
                child: AppEmptyState(
                  icon: Icons.receipt_long_rounded,
                  title:
                      vm.searchQuery.isNotEmpty
                          ? 'No se encontraron resultados'
                          : (vm.withDebtOnly
                              ? 'No hay créditos con deuda'
                              : 'No hay líneas de crédito registradas'),
                  message:
                      hasFilters
                          ? 'Intenta cambiar los filtros o realizar otra búsqueda.'
                          : 'Registra una línea de crédito para gestionar compras a crédito con proveedores.',
                  action:
                      hasFilters
                          ? OutlinedButton.icon(
                            onPressed: onClearFilters,
                            icon: const Icon(Icons.filter_alt_off_rounded),
                            label: const Text('Limpiar filtros'),
                          )
                          : ElevatedButton.icon(
                            onPressed: onCreateAccount,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Nuevo Crédito'),
                          ),
                ),
              );
            }

            // 4. Datos disponibles (Tabla o Cards) + Banner Degradado si falló revalidación
            final contentSliver =
                (isWide && isTableView)
                    ? SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: RepaintBoundary(
                          child: SupplierCreditsTable(
                            accounts: vm.accounts,
                            onSelectAccount: onAccountSelected,
                            onPay: onPay,
                            onViewHistory: onViewHistory,
                          ),
                        ),
                      ),
                    )
                    : _SupplierCreditsCardsSliver(
                      accounts: vm.accounts,
                      isWide: isWide,
                      selectedCreditIdNotifier: selectedCreditIdNotifier,
                      onAccountSelected: onAccountSelected,
                      onPay: onPay,
                      onViewHistory: onViewHistory,
                    );

            if (vm.loadFailure == null) return contentSliver;

            return SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: _DegradedErrorBanner(
                    message: vm.loadFailure!.message,
                    onRetry: () => cubit.loadAccounts(forceRefresh: true),
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

class _SupplierCreditsCardsSliver extends StatelessWidget {
  final List<SupplierCreditEntity> accounts;
  final bool isWide;
  final ValueNotifier<String?> selectedCreditIdNotifier;
  final ValueChanged<SupplierCreditEntity> onAccountSelected;
  final ValueChanged<SupplierCreditEntity> onPay;
  final ValueChanged<SupplierCreditEntity> onViewHistory;

  const _SupplierCreditsCardsSliver({
    required this.accounts,
    required this.isWide,
    required this.selectedCreditIdNotifier,
    required this.onAccountSelected,
    required this.onPay,
    required this.onViewHistory,
  });

  Widget _buildCard(BuildContext context, int index) {
    final account = accounts[index];
    return ValueListenableBuilder<String?>(
      valueListenable: selectedCreditIdNotifier,
      builder: (context, selectedId, _) {
        return RepaintBoundary(
          child: SupplierCreditCard(
            account: account,
            isSelected: selectedId == account.creditId,
            onTap: () => onAccountSelected(account),
            onPay: () => onPay(account),
            onViewHistory: () => onViewHistory(account),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isWide) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 420,
            mainAxisExtent: 220,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          delegate: SliverChildBuilderDelegate(
            _buildCard,
            childCount: accounts.length,
            addAutomaticKeepAlives: false,
            addRepaintBoundaries: false, // RepaintBoundary explícito arriba
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildCard(context, index),
          ),
          childCount: accounts.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: false,
        ),
      ),
    );
  }
}

class _DegradedErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DegradedErrorBanner({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: AppColors.warningDark,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Mostrando datos guardados · $message',
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
        ],
      ),
    );
  }
}

/// Skeleton de arranque en frío con UN ÚNICO AnimationController compartido
/// (bajo consumo de GPU/batería en dispositivos de gama baja).
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
