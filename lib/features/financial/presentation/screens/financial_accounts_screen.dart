import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/accounts_tab.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/movements_tab.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/shifts_tab.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/account_movements_cubit.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_cubit.dart';
import 'package:provider/provider.dart';

// FINANCIAL ACCOUNTS SCREEN

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
    // En tablet, el lado derecho tiene 2 pestaÃ±as: Movimientos y Turnos
    _tabletTabController = TabController(length: 2, vsync: this);

    // Fetch data initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FinancialAccountsCubit>().fetchAccounts();
        context.read<AccountMovementsCubit>().fetchMovements();

        final profileId = context.read<AuthCubit>().state.currentUser?.id;
        context.read<CashShiftsCubit>().setProfileFilter(profileId);
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
    return Column(
      children: [
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
