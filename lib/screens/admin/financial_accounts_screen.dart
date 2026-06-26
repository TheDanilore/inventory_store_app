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
    with TickerProviderStateMixin {
  late final TabController _mobileTabController;
  late final TabController _tabletTabController;

  @override
  void initState() {
    super.initState();
    _mobileTabController = TabController(length: 3, vsync: this);
    // En tablet, el lado derecho tiene 2 pestañas: Movimientos y Turnos
    _tabletTabController = TabController(length: 2, vsync: this);

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
    _mobileTabController.dispose();
    _tabletTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Finanzas',
      showBackButton: true,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              _buildGlobalBalanceHeader(),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth >= 720) {
                      return _buildTabletLayout();
                    }
                    return _buildMobileLayout();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlobalBalanceHeader() {
    return Consumer<FinancialAccountsProvider>(
      builder: (context, provider, _) {
        final accounts = provider.accounts;
        final activeAccounts = accounts.where((a) => a.isActive).toList();
        final totalBalance = activeAccounts.fold<double>(
          0.0,
          (sum, a) => sum + a.balance,
        );

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primary, Color(0xFF6C63FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Balance global (Activas)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'S/ ${totalBalance.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TabBar(
            controller: _mobileTabController,
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
              fontSize: 13,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            padding: const EdgeInsets.all(4), // Efecto Segmented Control
            tabs: const [
              Tab(
                icon: Icon(Icons.account_balance_wallet_rounded, size: 18),
                text: 'Cuentas',
                iconMargin: EdgeInsets.only(bottom: 4),
                height: 56,
              ),
              Tab(
                icon: Icon(Icons.swap_horiz_rounded, size: 18),
                text: 'Movimientos',
                iconMargin: EdgeInsets.only(bottom: 4),
                height: 56,
              ),
              Tab(
                icon: Icon(Icons.point_of_sale_rounded, size: 18),
                text: 'Turnos',
                iconMargin: EdgeInsets.only(bottom: 4),
                height: 56,
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedBuilder(
            animation: _mobileTabController.animation!,
            builder: (context, child) {
              return TabBarView(
                controller: _mobileTabController,
                physics: const BouncingScrollPhysics(),
                children: const [AccountsTab(), MovementsTab(), ShiftsTab()],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Master view: Accounts
        const Expanded(flex: 3, child: AccountsTab()),
        // Divider
        Container(
          width: 1,
          color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        ),
        // Detail view: Movements & Shifts
        Expanded(
          flex: 5,
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TabBar(
                  controller: _tabletTabController,
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
                    fontSize: 13,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  padding: const EdgeInsets.all(4),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.swap_horiz_rounded, size: 18),
                      text: 'Movimientos Recientes',
                      iconMargin: EdgeInsets.only(bottom: 4),
                      height: 56,
                    ),
                    Tab(
                      icon: Icon(Icons.point_of_sale_rounded, size: 18),
                      text: 'Turnos de Caja',
                      iconMargin: EdgeInsets.only(bottom: 4),
                      height: 56,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabletTabController,
                  physics: const BouncingScrollPhysics(),
                  children: const [MovementsTab(), ShiftsTab()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
