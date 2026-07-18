import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts_state.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/account_form_sheet.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';

class AccountsTab extends StatefulWidget {
  const AccountsTab({super.key});

  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<AccountsTab> {
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<bool> _isFabExtended = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.offset > 10 && _isFabExtended.value) {
        _isFabExtended.value = false;
      } else if (_scrollController.offset <= 10 && !_isFabExtended.value) {
        _isFabExtended.value = true;
      }
    });
  }

  @override
  void dispose() {
    _isFabExtended.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FinancialAccountsCubit, FinancialAccountsState>(
      builder: (context, state) {
        final accounts =
            state is FinancialAccountsLoaded
                ? state.accounts
                : <FinancialAccountEntity>[];
        final isLoading = state is FinancialAccountsLoading;

        final activeAccounts = accounts.where((a) => a.isActive).toList();
        final inactiveAccounts = accounts.where((a) => !a.isActive).toList();

        return Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child:
                      isLoading && accounts.isEmpty
                          ? const _AccountsSkeleton()
                          : accounts.isEmpty
                          ? const AppEmptyState(
                            icon: Icons.account_balance_wallet_rounded,
                            title: 'Sin Cuentas',
                            message: 'No hay cuentas financieras registradas.',
                          )
                          : RefreshIndicator(
                            onRefresh:
                                () async =>
                                    context
                                        .read<FinancialAccountsCubit>()
                                        .fetchAccounts(),
                            child: AnimationLimiter(
                              child: ListView(
                                controller: _scrollController,
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  80,
                                ),
                                children: [
                                  _buildGlobalBalanceCard(activeAccounts),
                                  if (activeAccounts.isNotEmpty) ...[
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        top: 12,
                                        bottom: 10,
                                        left: 4,
                                      ),
                                      child: Text(
                                        'CUENTAS ACTIVAS',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textSecondary,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                    ...activeAccounts.asMap().entries.map(
                                      (
                                        entry,
                                      ) => AnimationConfiguration.staggeredList(
                                        position: entry.key,
                                        duration: const Duration(
                                          milliseconds: 375,
                                        ),
                                        child: SlideAnimation(
                                          verticalOffset: 50.0,
                                          child: FadeInAnimation(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: _AccountCard(
                                                account: entry.value,
                                                onEdit:
                                                    () => AccountFormSheet.show(
                                                      context,
                                                      account: entry.value,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (inactiveAccounts.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        bottom: 10,
                                        left: 4,
                                      ),
                                      child: Text(
                                        'CUENTAS INACTIVAS',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textSecondary,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ),
                                    ...inactiveAccounts.asMap().entries.map(
                                      (
                                        entry,
                                      ) => AnimationConfiguration.staggeredList(
                                        position:
                                            activeAccounts.length + entry.key,
                                        duration: const Duration(
                                          milliseconds: 375,
                                        ),
                                        child: SlideAnimation(
                                          verticalOffset: 50.0,
                                          child: FadeInAnimation(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: _AccountCard(
                                                account: entry.value,
                                                onEdit:
                                                    () => AccountFormSheet.show(
                                                      context,
                                                      account: entry.value,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                ),
              ],
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'fab_accounts',
                onPressed:
                    isLoading
                        ? null
                        : () {
                          // Solo vibrar si no es web para evitar MissingPluginException
                          if (!kIsWeb) {
                            Vibration.vibrate(duration: 50, amplitude: 128);
                          }
                          AccountFormSheet.show(context);
                        },
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: ValueListenableBuilder<bool>(
                  valueListenable: _isFabExtended,
                  builder: (context, isExtended, _) {
                    return AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child:
                          isExtended
                              ? const Text(
                                'Nueva Cuenta',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                              : const SizedBox.shrink(),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlobalBalanceCard(List<FinancialAccountEntity> activeAccounts) {
    final totalBalance = activeAccounts.fold<double>(
      0.0,
      (sum, a) => sum + a.balance,
    );

    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
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
  }
}

class _AccountCard extends StatelessWidget {
  final FinancialAccountEntity account;
  final VoidCallback onEdit;

  const _AccountCard({required this.account, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isBank = account.type == 'BANCO';
    final isDigital = account.type == 'DIGITAL';
    final iconColor =
        account.isActive
            ? (isBank
                ? const Color(0xFF0288D1)
                : isDigital
                ? const Color(0xFF8E24AA)
                : AppColors.success)
            : AppColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: account.isActive ? Colors.white : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: account.isActive ? Colors.transparent : AppColors.border,
        ),
        boxShadow:
            account.isActive
                ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        account.isActive
                            ? iconColor.withValues(alpha: 0.1)
                            : AppColors.surfaceDark,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIcon(account.type),
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color:
                              account.isActive
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          account.type,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'S/ ${account.balance.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color:
                            account.isActive
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.isActive ? 'Activa' : 'Inactiva',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            account.isActive
                                ? AppColors.success
                                : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    if (type == 'CAJA') return Icons.point_of_sale_rounded;
    if (type == 'BANCO') return Icons.account_balance_rounded;
    if (type == 'DIGITAL') return Icons.phone_android_rounded;
    return Icons.savings_rounded;
  }
}

class _AccountsSkeleton extends StatelessWidget {
  const _AccountsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const AppShimmer(width: 48, height: 48, isCircular: true),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    AppShimmer(width: 120, height: 16),
                    SizedBox(height: 8),
                    AppShimmer(width: 60, height: 12),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  AppShimmer(width: 80, height: 16),
                  SizedBox(height: 8),
                  AppShimmer(width: 40, height: 12),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
