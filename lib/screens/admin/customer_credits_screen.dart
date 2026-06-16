import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/admin/customer_credits_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:inventory_store_app/screens/admin/widgets/customer_credits/global_stats_bar.dart';
import 'package:inventory_store_app/screens/admin/widgets/customer_credits/credit_account_card.dart';
import 'package:inventory_store_app/screens/admin/widgets/customer_credits/credit_account_modal.dart';
import 'package:inventory_store_app/screens/admin/widgets/customer_credits/register_payment_modal.dart';
import 'package:inventory_store_app/screens/admin/customer_credit_movements_screen.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';

class CustomerCreditsScreen extends StatefulWidget {
  const CustomerCreditsScreen({super.key});

  @override
  State<CustomerCreditsScreen> createState() => _CustomerCreditsScreenState();
}

class _CustomerCreditsScreenState extends State<CustomerCreditsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<CustomerCreditsProvider>();
      provider.init();

      _tabController.addListener(() {
        if (!_tabController.indexIsChanging) {
          provider.setTab(_tabController.index);
        }
      });
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
        context.read<CustomerCreditsProvider>().setSearch(query);
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
              if (mounted) context.read<CustomerCreditsProvider>().fetchPage();
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Créditos de Clientes',
      showBackButton: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateAccountModal,
        backgroundColor: AppColors.teal,
        icon: const Icon(Icons.domain_add_rounded, color: Colors.white),
        label: const Text(
          'Nuevo Crédito',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Consumer<CustomerCreditsProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // Métricas Globales
              if (!provider.isLoading)
                GlobalStatsBar(
                  totalDebt: provider.totalDebt,
                  activeAccounts: provider.activeAccounts,
                  suspendedAccounts: provider.suspendedAccounts,
                  maxedOutAccounts: provider.maxedOutAccounts,
                ),

              // Barra de Búsqueda y Tabs
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                        fillColor: AppColors.bg,
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
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        labelColor: Colors.white,
                        unselectedLabelColor: AppColors.textMuted,
                        indicator: BoxDecoration(
                          color: AppColors.teal,
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
                                if (provider.accounts.any(
                                  (a) => a.currentDebt > 0 && a.isActive,
                                )) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.danger,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${provider.accounts.where((a) => a.currentDebt > 0 && a.isActive).length}',
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
                    const SizedBox(height: 4),
                  ],
                ),
              ),

              // Lista o Carga
              Expanded(
                child:
                    provider.isLoading && provider.accounts.isEmpty
                        ? const _CustomerCreditsSkeleton()
                        : provider.errorMessage.isNotEmpty &&
                            provider.accounts.isEmpty
                        ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              'Error: ${provider.errorMessage}',
                              style: const TextStyle(color: AppColors.danger),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                        : provider.accounts.isEmpty
                        ? _buildEmptyState()
                        : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: provider.accounts.length,
                          separatorBuilder:
                              (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final account = provider.accounts[index];
                            return CreditAccountCard(
                              account: account,
                              onTap:
                                  () => _showAccountOptions(
                                    context,
                                    account,
                                    provider,
                                  ),
                            );
                          },
                        ),
              ),

              if (!provider.isLoading && provider.totalPages > 1)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: AdminPageBlocks(
                    currentPage: provider.currentPage,
                    totalPages: provider.totalPages,
                    onPageChanged: (page) => provider.setPage(page),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.credit_card_off_rounded,
            size: 64,
            color: AppColors.border,
          ),
          const SizedBox(height: 16),
          const Text(
            'No se encontraron cuentas',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Puedes crear una nueva línea de crédito\nusando el botón superior.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  void _showAccountOptions(
    BuildContext context,
    var account,
    CustomerCreditsProvider provider,
  ) {
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
                  account.partnerName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Opciones de cuenta'),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.history_rounded,
                  color: AppColors.teal,
                ),
                title: const Text('Ver historial de movimientos'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => CustomerCreditMovementsScreen(
                            creditId: account.creditId,
                            customerName: account.partnerName,
                            currentDebt: account.currentDebt,
                            creditLimit: account.creditLimit,
                          ),
                    ),
                  ).then((_) => provider.fetchPage());
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.payments_rounded,
                  color: AppColors.success,
                ),
                title: const Text('Registrar Pago / Abono'),
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
                            onPaymentSaved: () => provider.fetchPage(),
                          ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded, color: AppColors.teal),
                title: const Text('Editar Límite de Crédito'),
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder:
                        (ctx3) => CreditAccountModal(
                          accountToEdit: account,
                          onSaved: () => provider.fetchPage(),
                        ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  account.isActive
                      ? Icons.block_rounded
                      : Icons.check_circle_rounded,
                  color:
                      account.isActive ? AppColors.danger : AppColors.success,
                ),
                title: Text(
                  account.isActive ? 'Suspender Línea' : 'Reactivar Línea',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await provider.toggleAccountStatus(account);
                    if (mounted) {
                      AppSnackbar.show(
                        context,
                        message:
                            account.isActive
                                ? 'Línea de crédito suspendida'
                                : 'Línea de crédito reactivada',
                        type: SnackbarType.success,
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      AppSnackbar.show(
                        context,
                        message: 'Error al cambiar estado: $e',
                        type: SnackbarType.error,
                      );
                    }
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
