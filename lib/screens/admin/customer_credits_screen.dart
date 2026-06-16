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
      builder: (ctx) => CreditAccountModal(
        onSaved: () {
          if (mounted) context.read<CustomerCreditsProvider>().fetchPage();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Créditos de Clientes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'Nueva línea de crédito',
            onPressed: _openCreateAccountModal,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Todas'),
            Tab(text: 'Con Deuda'),
          ],
        ),
      ),
      body: Consumer<CustomerCreditsProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              // Barra de Búsqueda
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Buscar cliente, DNI o teléfono...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),

              // Métricas Globales
              GlobalStatsBar(
                totalDebt: provider.totalDebt,
                activeAccounts: provider.activeAccounts,
                suspendedAccounts: provider.suspendedAccounts,
                maxedOutAccounts: provider.maxedOutAccounts,
              ),

              const SizedBox(height: 16),

              // Lista o Carga
              Expanded(
                child: provider.isLoading && provider.accounts.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : provider.errorMessage.isNotEmpty && provider.accounts.isEmpty
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
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: provider.accounts.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final account = provider.accounts[index];
                                  return CreditAccountCard(
                                    account: account,
                                    onTap: () => _showAccountOptions(context, account, provider),
                                  );
                                },
                              ),
              ),

              // Paginación
              if (provider.totalPages > 1)
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Página ${provider.currentPage + 1} de ${provider.totalPages}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            onPressed: provider.currentPage > 0
                                ? () => provider.setPage(provider.currentPage - 1)
                                : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            onPressed: provider.currentPage < provider.totalPages - 1
                                ? () => provider.setPage(provider.currentPage + 1)
                                : null,
                          ),
                        ],
                      ),
                    ],
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
          Icon(Icons.credit_card_off_rounded, size: 64, color: AppColors.border),
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
      BuildContext context, var account, CustomerCreditsProvider provider) {
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
                leading: const Icon(Icons.payments_rounded, color: AppColors.success),
                title: const Text('Registrar Pago / Abono'),
                enabled: account.isActive && account.currentDebt > 0,
                onTap: () {
                  Navigator.pop(ctx);
                  if (account.isActive && account.currentDebt > 0) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx2) => RegisterPaymentModal(
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
                    builder: (ctx3) => CreditAccountModal(
                      accountToEdit: account,
                      onSaved: () => provider.fetchPage(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: Icon(
                  account.isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                  color: account.isActive ? AppColors.danger : AppColors.success,
                ),
                title: Text(account.isActive ? 'Suspender Línea' : 'Reactivar Línea'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await provider.toggleAccountStatus(account);
                    if (mounted) {
                      AppSnackbar.show(
                        context,
                        message: account.isActive
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
