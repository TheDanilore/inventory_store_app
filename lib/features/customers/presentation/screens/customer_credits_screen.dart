import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit_list_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit_list_state.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/credit_account_card.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/global_stats_bar.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/credit_account_modal.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/register_payment_modal.dart';

class CustomerCreditsScreen extends StatelessWidget {
  const CustomerCreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<CustomerCreditListCubit>()..init(),
      child: const _CustomerCreditsScreenContent(),
    );
  }
}

class _CustomerCreditsScreenContent extends StatefulWidget {
  const _CustomerCreditsScreenContent();

  @override
  State<_CustomerCreditsScreenContent> createState() =>
      _CustomerCreditsScreenContentState();
}

class _CustomerCreditsScreenContentState
    extends State<_CustomerCreditsScreenContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<CustomerCreditListCubit>().setTab(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        context.read<CustomerCreditListCubit>().setSearch(query);
      }
    });
  }

  void _openCreateAccountModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => CreditAccountModal(
            onSaved: () {
              if (mounted) context.read<CustomerCreditListCubit>().loadData();
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CustomerCreditListCubit, CustomerCreditListState>(
      builder: (context, state) {
        return AdminLayout(
          title: 'Cuentas por Cobrar',
          showBackButton: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refrescar',
              onPressed: () {
                context.read<CustomerCreditListCubit>().loadData();
              },
            ),
          ],
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _openCreateAccountModal,
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.domain_add_rounded, color: Colors.white),
            label: const Text(
              'Nuevo Crédito',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh:
                      () async =>
                          context.read<CustomerCreditListCubit>().loadData(),
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      // Stats Bar
                      if (!state.isLoading || state.accounts.isNotEmpty)
                        SliverToBoxAdapter(
                          child: GlobalStatsBar(
                            totalDebt: state.totalDebt,
                            activeAccounts: state.activeAccounts,
                            suspendedAccounts: state.suspendedAccounts,
                            maxedOutAccounts: state.maxedOutAccounts,
                          ),
                        ),
                      // Search and Tabs
                      SliverToBoxAdapter(
                        child: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Column(
                            children: [
                              TextField(
                                controller: _searchCtrl,
                                onChanged: _onSearchChanged,
                                decoration: InputDecoration(
                                  hintText: 'Buscar cliente, DNI o teléfono...',
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    color: AppColors.textMuted,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.background,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: TabBar(
                                  controller: _tabController,
                                  labelColor: Colors.white,
                                  unselectedLabelColor: AppColors.textMuted,
                                  indicator: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  indicatorSize: TabBarIndicatorSize.tab,
                                  dividerColor: Colors.transparent,
                                  padding: const EdgeInsets.all(4),
                                  tabs: [
                                    const Tab(text: 'Todas'),
                                    Tab(
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text('Con Deuda'),
                                          if (state.accounts.any(
                                            (a) =>
                                                a.currentDebt > 0 && a.isActive,
                                          )) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.error,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                '${state.accounts.where((a) => a.currentDebt > 0 && a.isActive).length}',
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Content states
                      if (state.isLoading && state.accounts.isEmpty)
                        const SliverToBoxAdapter(
                          child: _CustomerCreditsSkeleton(),
                        )
                      else if (state.errorMessage.isNotEmpty &&
                          state.accounts.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: AppEmptyState(
                            icon: Icons.error_outline_rounded,
                            color: AppColors.error,
                            title: 'Error',
                            message: state.errorMessage,
                          ),
                        )
                      else if (state.accounts.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: AppEmptyState(
                            icon: Icons.credit_card_off_rounded,
                            title: 'No se encontraron cuentas',
                            message:
                                'Puedes crear una nueva línea de crédito\nusando el botón superior.',
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              final account = state.accounts[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: CreditAccountCard(
                                  account: account,
                                  onTap:
                                      () =>
                                          _showAccountOptions(context, account),
                                ),
                              );
                            }, childCount: state.accounts.length),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (!state.isLoading && state.totalPages > 1)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: AdminPageBlocks(
                      currentPage: state.currentPage,
                      totalPages: state.totalPages,
                      onPageChanged:
                          (page) => context
                              .read<CustomerCreditListCubit>()
                              .setPage(page),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAccountOptions(BuildContext context, CustomerCreditEntity account) {
    final cubit = context.read<CustomerCreditListCubit>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                title: Text(
                  account.customerName ?? 'Cliente',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Opciones de cuenta'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.history_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Ver historial de movimientos',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  context
                      .push(
                        '/admin/customer-credit-movements/${account.id}?name=${Uri.encodeComponent(account.customerName ?? '')}&debt=${account.currentDebt}&limit=${account.creditLimit}',
                        extra: {
                          'customerName': account.customerName,
                          'currentDebt': account.currentDebt,
                          'creditLimit': account.creditLimit,
                        },
                      )
                      .then((_) => cubit.loadData());
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.payments_rounded,
                  color: AppColors.success,
                ),
                title: const Text(
                  'Registrar Pago / Abono',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                enabled: account.isActive && account.currentDebt > 0,
                onTap: () {
                  Navigator.pop(ctx);
                  if (account.isActive && account.currentDebt > 0) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder:
                          (ctx2) => RegisterPaymentModal(
                            account: account,
                            onSaved: () => cubit.loadData(),
                            onSavePayment: (amount, method, notes) async {
                              await cubit.registerPayment(
                                creditId: account.id,
                                amount: amount,
                                paymentMethod: method,
                                notes: notes,
                              );
                            },
                          ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.edit_rounded,
                  color: AppColors.primary,
                ),
                title: const Text(
                  'Editar Límite de Crédito',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder:
                        (ctx3) => CreditAccountModal(
                          accountToEdit: account,
                          onSaved: () => cubit.loadData(),
                        ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  account.isActive
                      ? Icons.block_rounded
                      : Icons.check_circle_rounded,
                  color: account.isActive ? AppColors.error : AppColors.success,
                ),
                title: Text(
                  account.isActive ? 'Suspender Línea' : 'Reactivar Línea',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await cubit.toggleAccountStatus(
                      account.id,
                      account.isActive,
                    );
                    if (!context.mounted) return;
                    AppSnackbar.show(
                      context,
                      message:
                          account.isActive
                              ? 'Línea de crédito suspendida'
                              : 'Línea de crédito reactivada',
                      type: SnackbarType.success,
                    );
                  } catch (e) {
                    if (!context.mounted) return;
                    AppSnackbar.show(
                      context,
                      message: 'Error al cambiar estado: $e',
                      type: SnackbarType.error,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CustomerCreditsSkeleton extends StatelessWidget {
  const _CustomerCreditsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 6,
      physics: const NeverScrollableScrollPhysics(),
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  AppShimmer(width: 140, height: 16, borderRadius: 4),
                  AppShimmer(width: 60, height: 12, borderRadius: 4),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppShimmer(width: 50, height: 10, borderRadius: 2),
                      SizedBox(height: 4),
                      AppShimmer(width: 80, height: 18, borderRadius: 4),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppShimmer(width: 50, height: 10, borderRadius: 2),
                      SizedBox(height: 4),
                      AppShimmer(width: 60, height: 18, borderRadius: 4),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
