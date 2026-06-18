import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/admin/widgets/financial/accounts_tab.dart';
import 'package:inventory_store_app/screens/admin/widgets/financial/movements_tab.dart';
import 'package:inventory_store_app/screens/admin/widgets/financial/shifts_tab.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/admin/financial_accounts_provider.dart';
import 'package:inventory_store_app/providers/admin/account_movements_provider.dart';
import 'package:inventory_store_app/providers/admin/cash_shifts_provider.dart';

// ══════════════════════════════════════════════════════════════════════════════
// FINANCIAL ACCOUNTS SCREEN — Cuentas · Movimientos · Turnos de Caja
// ══════════════════════════════════════════════════════════════════════════════

class FinancialAccountsScreen extends StatefulWidget {
  const FinancialAccountsScreen({super.key});

  @override
  State<FinancialAccountsScreen> createState() =>
      _FinancialAccountsScreenState();
}

class _FinancialAccountsScreenState extends State<FinancialAccountsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Fetch data initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FinancialAccountsProvider>().fetchAccounts();
        context.read<AccountMovementsProvider>().fetchMovements();
        context.read<CashShiftsProvider>().fetchShifts();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Finanzas',
      showBackButton: true,
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.account_balance_wallet_rounded, size: 17),
                  text: 'Cuentas',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: Icon(Icons.swap_horiz_rounded, size: 17),
                  text: 'Movimientos',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: Icon(Icons.point_of_sale_rounded, size: 17),
                  text: 'Turnos',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [AccountsTab(), MovementsTab(), ShiftsTab()],
            ),
          ),
        ],
      ),
    );
  }
}
