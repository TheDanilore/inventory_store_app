import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_state.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_global_stats_bar.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_credit_card.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_account_options_sheet.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_credit_account_sheet.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';

class SupplierCreditsScreen extends StatefulWidget {
  const SupplierCreditsScreen({super.key});

  @override
  State<SupplierCreditsScreen> createState() => _SupplierCreditsScreenState();
}

class _SupplierCreditsScreenState extends State<SupplierCreditsScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(_onTabChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<SupplierCreditsCubit>();
      final currentState = cubit.state;
      if (currentState is SupplierCreditsLoaded) {
        _searchCtrl.text = currentState.searchQuery;
        _tabCtrl.index = currentState.withDebtOnly ? 1 : 0;
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;
    context.read<SupplierCreditsCubit>().setWithDebtOnly(_tabCtrl.index == 1);
  }

  void _openCreateAccountModal() {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final modal = SupplierCreditAccountSheet(
      isDialog: isDesktop, // Pasamos el parámetro explícitamente
      onSaved: () {
        context.read<SupplierCreditsCubit>().loadAccounts(refresh: true);
      },
    );

    if (isDesktop) {
      showDialog(context: context, builder: (_) => modal);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => modal,
      );
    }
  }

  void _openAccountOptions(BuildContext context, SupplierCreditEntity account) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final modal = SupplierAccountOptionsSheet(
      account: account,
      isDialog: isDesktop,
      onRefresh: () {
        context.read<SupplierCreditsCubit>().loadAccounts();
      },
      onToggleStatus: (acc) async {
        context.read<SupplierCreditsCubit>().toggleAccountStatus(acc);
        if (context.mounted) {
          AppSnackbar.show(
            context,
            message:
                acc.isActive ? 'Crédito suspendido.' : 'Crédito reactivado.',
            type: SnackbarType.success,
          );
        }
      },
    );

    if (isDesktop) {
      showDialog(context: context, builder: (_) => modal);
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => modal,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return BlocListener<SupplierCreditsCubit, SupplierCreditsState>(
      listener: (context, state) {
        if (state is SupplierCreditsError) {
          AppSnackbar.show(
            context,
            message: state.message,
            type: SnackbarType.error,
          );
          context.read<SupplierCreditsCubit>().clearError();
        }
      },
      child: AdminLayout(
        title: 'Créditos de Proveedores',
        showBackButton: true,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openCreateAccountModal,
          backgroundColor: Colors.blue.shade700,
          icon: const Icon(Icons.domain_add_rounded, color: Colors.white),
          label: const Text(
            'Nueva Línea',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: BlocBuilder<SupplierCreditsCubit, SupplierCreditsState>(
          builder: (context, state) {
            final isLoading =
                state is SupplierCreditsLoading ||
                state is SupplierCreditsInitial;
            final isError = state is SupplierCreditsError;

            List<SupplierCreditEntity> accounts = [];
            bool withDebtOnly = false;
            int currentPage = 0;
            int totalPages = 1;
            Map<String, dynamic> stats = {};
            String? errorMessage;

            if (state is SupplierCreditsLoaded) {
              accounts = state.accounts;
              withDebtOnly = state.withDebtOnly;
              currentPage = state.currentPage;
              totalPages = state.totalPages;
              stats = state.stats;
            } else if (state is SupplierCreditsLoading) {
              accounts = state.currentAccounts;
              withDebtOnly = state.withDebtOnly;
              currentPage = state.currentPage;
              totalPages =
                  state.totalCount == 0 ? 1 : (state.totalCount / 8).ceil();
              stats = state.stats;
            } else if (state is SupplierCreditsError) {
              accounts = state.currentAccounts;
              withDebtOnly = state.withDebtOnly;
              currentPage = state.currentPage;
              totalPages =
                  state.totalCount == 0 ? 1 : (state.totalCount / 8).ceil();
              stats = state.stats;
              errorMessage = state.message;
            }

            final totalDebt =
                double.tryParse(stats['totalDebt']?.toString() ?? '0') ?? 0.0;
            final activeAccounts =
                int.tryParse(stats['activeAccounts']?.toString() ?? '0') ?? 0;
            final suspendedAccounts =
                int.tryParse(stats['suspendedAccounts']?.toString() ?? '0') ??
                0;
            final maxedOutAccounts =
                int.tryParse(stats['maxedOutAccounts']?.toString() ?? '0') ?? 0;
            final debtCount =
                int.tryParse(stats['debtCount']?.toString() ?? '0') ?? 0;

            // CONTENEDOR PRINCIPAL RESTRINGIDO AL CENTRO
            return Center(
              child: RefreshIndicator(
                onRefresh:
                    () => context.read<SupplierCreditsCubit>().loadAccounts(
                      refresh: true,
                    ),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          SupplierGlobalStatsBar(
                            totalDebt: totalDebt,
                            activeAccounts: activeAccounts,
                            suspendedAccounts: suspendedAccounts,
                            maxedOutAccounts: maxedOutAccounts,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                            child: Column(
                              children: [
                                TextField(
                                  controller: _searchCtrl,
                                  onChanged:
                                      context
                                          .read<SupplierCreditsCubit>()
                                          .setSearchQuery,
                                  decoration: InputDecoration(
                                    hintText: 'Buscar por proveedor o RUC...',
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      color: AppColors.textMuted,
                                    ),
                                    suffixIcon:
                                        _searchCtrl.text.isNotEmpty
                                            ? IconButton(
                                              icon: const Icon(
                                                Icons.clear_rounded,
                                                color: AppColors.textMuted,
                                              ),
                                              onPressed: () {
                                                _searchCtrl.clear();
                                                context
                                                    .read<
                                                      SupplierCreditsCubit
                                                    >()
                                                    .setSearchQuery('');
                                              },
                                            )
                                            : null,
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
                                    controller: _tabCtrl,
                                    indicatorSize: TabBarIndicatorSize.tab,
                                    dividerColor: Colors.transparent,
                                    indicator: BoxDecoration(
                                      color: Colors.blue.shade700,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    labelColor: Colors.white,
                                    unselectedLabelColor: AppColors.textMuted,
                                    tabs: [
                                      const Tab(text: 'Todas'),
                                      Tab(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Text('Por Pagar'),
                                            if (debtCount > 0) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 1,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.danger,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '$debtCount',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
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
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    // CONDICIONAL: GRID EN DESKTOP, LISTA EN MÓVIL
                    if (isLoading && accounts.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver:
                            isDesktop
                                ? SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 400,
                                        mainAxisExtent: 165,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => const AppShimmer(
                                      width: double.infinity,
                                      height: double.infinity,
                                      borderRadius: 16,
                                    ),
                                    childCount: 6,
                                  ),
                                )
                                : SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => const Padding(
                                      padding: EdgeInsets.only(bottom: 12),
                                      child: AppShimmer(
                                        width: double.infinity,
                                        height: 120,
                                        borderRadius: 16,
                                      ),
                                    ),
                                    childCount: 5,
                                  ),
                                ),
                      )
                    else if (isError &&
                        errorMessage != null &&
                        accounts.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: AppEmptyState(
                          icon: Icons.error_outline_rounded,
                          color: AppColors.danger,
                          title: 'Ocurrió un error',
                          message: errorMessage,
                          action: ElevatedButton.icon(
                            onPressed:
                                () => context
                                    .read<SupplierCreditsCubit>()
                                    .loadAccounts(refresh: true),
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reintentar'),
                          ),
                        ),
                      )
                    else if (accounts.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: AppEmptyState(
                          icon: Icons.receipt_long_rounded,
                          title:
                              _searchCtrl.text.isNotEmpty
                                  ? 'No se encontraron resultados'
                                  : (withDebtOnly
                                      ? 'No hay créditos con deuda'
                                      : 'No hay líneas de crédito registradas'),
                          message:
                              'Intenta cambiar los filtros o realizar otra búsqueda.',
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver:
                            isDesktop
                                ? SliverGrid(
                                  gridDelegate:
                                      const SliverGridDelegateWithMaxCrossAxisExtent(
                                        maxCrossAxisExtent: 400,
                                        mainAxisExtent: 165,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final account = accounts[index];
                                    return SupplierCreditCard(
                                      account: account,
                                      onTap:
                                          () => _openAccountOptions(
                                            context,
                                            account,
                                          ),
                                    );
                                  }, childCount: accounts.length),
                                )
                                : SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final account = accounts[index];
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: SupplierCreditCard(
                                        account: account,
                                        onTap:
                                            () => _openAccountOptions(
                                              context,
                                              account,
                                            ),
                                      ),
                                    );
                                  }, childCount: accounts.length),
                                ),
                      ),

                    if (!isLoading && totalPages > 1)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                          child: AdminPageBlocks(
                            currentPage: currentPage,
                            totalPages: totalPages,
                            onPageChanged:
                                context.read<SupplierCreditsCubit>().setPage,
                          ),
                        ),
                      )
                    else
                      const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
