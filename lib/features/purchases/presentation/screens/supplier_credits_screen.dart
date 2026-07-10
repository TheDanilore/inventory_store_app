import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';
import 'package:provider/provider.dart';

import 'package:inventory_store_app/features/purchases/presentation/providers/supplier_credits_provider.dart';
import 'package:inventory_store_app/core/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/main_navigation/presentation/widgets/admin_layout.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';

// Widgets extraÃ­dos
import 'package:inventory_store_app/features/purchases/presentation/screens/widgets/supplier_credits/supplier_global_stats_bar.dart';
import 'package:inventory_store_app/features/purchases/presentation/screens/widgets/supplier_credits/supplier_credit_card.dart';
import 'package:inventory_store_app/features/purchases/presentation/screens/widgets/supplier_credits/supplier_account_options_sheet.dart';
import 'package:inventory_store_app/features/purchases/presentation/screens/widgets/supplier_credits/supplier_credit_account_modal.dart';

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
      final provider = context.read<SupplierCreditsProvider>();
      _searchCtrl.text = provider.searchQuery;
      // Setup initial tab based on provider state
      _tabCtrl.index = provider.withDebtOnly ? 1 : 0;
      provider.fetchAccounts();
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
    final provider = context.read<SupplierCreditsProvider>();
    provider.setWithDebtOnly(_tabCtrl.index == 1);
  }

  void _openCreateAccountModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => SupplierCreditAccountModal(
            onSaved: () {
              context.read<SupplierCreditsProvider>().fetchAccounts();
            },
          ),
    );
  }

  void _openAccountOptions(BuildContext context, dynamic account) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (_) => SupplierAccountOptionsSheet(
            account: account,
            onRefresh: () {
              context.read<SupplierCreditsProvider>().fetchAccounts(
                showLoading: false,
              );
            },
            onToggleStatus: (acc) async {
              try {
                await context
                    .read<SupplierCreditsProvider>()
                    .toggleAccountStatus(acc.creditId, acc.isActive);
                if (context.mounted) {
                  AppSnackbar.show(
                    context,
                    message:
                        acc.isActive
                            ? 'CrÃ©dito suspendido.'
                            : 'CrÃ©dito reactivado.',
                    type: SnackbarType.success,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  AppSnackbar.show(
                    context,
                    message: 'Error al cambiar estado: $e',
                    type: SnackbarType.error,
                  );
                }
              }
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Cuentas por Pagar',
      showBackButton: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateAccountModal,
        backgroundColor: Colors.blue.shade700,
        icon: const Icon(Icons.domain_add_rounded, color: Colors.white),
        label: const Text(
          'Nueva LÃ­nea',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<SupplierCreditsProvider>(
        builder: (context, provider, child) {
          return RefreshIndicator(
            onRefresh: () => provider.fetchAccounts(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Stats Bar
                      SupplierGlobalStatsBar(
                        totalDebt: provider.totalDebt,
                        activeAccounts: provider.activeAccounts,
                        suspendedAccounts: provider.suspendedAccounts,
                        maxedOutAccounts: provider.maxedOutAccounts,
                      ),
                      const SizedBox(height: 16),

                      // Buscador y Tabs integrados
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
                              onChanged: provider.setSearchQuery,
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
                                            provider.setSearchQuery('');
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
                                        if (provider.debtCount > 0) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.danger,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '${provider.debtCount}',
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

                // Contenido principal
                if (provider.isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
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
                else if (provider.errorMessage != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon: Icons.error_outline_rounded,
                      color: AppColors.danger,
                      title: 'OcurriÃ³ un error',
                      message: provider.errorMessage ?? '',
                      action: ElevatedButton.icon(
                        onPressed: provider.fetchAccounts,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                      ),
                    ),
                  )
                else if (provider.accounts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: AppEmptyState(
                      icon: Icons.receipt_long_rounded,
                      title:
                          _searchCtrl.text.isNotEmpty
                              ? 'No se encontraron resultados'
                              : (provider.withDebtOnly
                                  ? 'No hay crÃ©ditos con deuda'
                                  : 'No hay lÃ­neas de crÃ©dito registradas'),
                      message:
                          'Intenta cambiar los filtros o realizar otra bÃºsqueda.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final account = provider.accounts[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SupplierCreditCard(
                            account: account,
                            onTap: () => _openAccountOptions(context, account),
                          ),
                        );
                      }, childCount: provider.accounts.length),
                    ),
                  ),

                // PaginaciÃ³n
                if (!provider.isLoading && provider.totalPages > 1)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      child: AdminPageBlocks(
                        currentPage: provider.currentPage,
                        totalPages: provider.totalPages,
                        onPageChanged: (page) {
                          provider.setPage(page);
                        },
                      ),
                    ),
                  )
                else
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          );
        },
      ),
    );
  }
}

