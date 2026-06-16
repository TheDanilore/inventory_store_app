import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/financial_account_model.dart';
import 'package:inventory_store_app/providers/admin/financial_accounts_provider.dart';
import 'package:inventory_store_app/screens/admin/widgets/financial/account_form_sheet.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';
import 'package:provider/provider.dart';

class AccountsTab extends StatelessWidget {
  const AccountsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FinancialAccountsProvider>(
      builder: (context, provider, _) {
        final accounts = provider.accounts;
        final isLoading = provider.isLoading;

        final activeAccounts = accounts.where((a) => a.isActive).toList();
        final inactiveAccounts = accounts.where((a) => !a.isActive).toList();

        final totalBalance = activeAccounts.fold<double>(
          0.0,
          (sum, a) => sum + a.balance,
        );

        return Stack(
          children: [
            Column(
              children: [
                _GlobalBalanceCard(totalBalance: totalBalance),
                Expanded(
                  child: isLoading && accounts.isEmpty
                      ? const _AccountsSkeleton()
                      : accounts.isEmpty
                          ? const _EmptyState()
                          : RefreshIndicator(
                              onRefresh: () async => provider.fetchAccounts(),
                              child: ListView(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                                children: [
                                  if (activeAccounts.isNotEmpty) ...[
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 10, left: 4),
                                      child: Text('CUENTAS ACTIVAS',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textSecondary,
                                            letterSpacing: 1.2,
                                          )),
                                    ),
                                    ...activeAccounts.map((a) => Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: _AccountCard(
                                            account: a,
                                            onEdit: () => AccountFormSheet.show(context, account: a),
                                          ),
                                        )),
                                  ],
                                  if (inactiveAccounts.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 10, left: 4),
                                      child: Text('CUENTAS INACTIVAS',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textSecondary,
                                            letterSpacing: 1.2,
                                          )),
                                    ),
                                    ...inactiveAccounts.map((a) => Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: _AccountCard(
                                            account: a,
                                            onEdit: () => AccountFormSheet.show(context, account: a),
                                          ),
                                        )),
                                  ],
                                ],
                              ),
                            ),
                ),
              ],
            ),
            Positioned(
              bottom: 24,
              right: 16,
              child: FloatingActionButton(
                heroTag: 'fab_accounts',
                onPressed: isLoading ? null : () => AccountFormSheet.show(context),
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GlobalBalanceCard extends StatelessWidget {
  final double totalBalance;
  const _GlobalBalanceCard({required this.totalBalance});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
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
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Balance total (Activas)',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  'S/ ${totalBalance.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5),
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
  final FinancialAccountModel account;
  final VoidCallback onEdit;

  const _AccountCard({required this.account, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final isBank = account.type == 'BANCO';
    final isDigital = account.type == 'DIGITAL';
    final iconColor = account.isActive
        ? (isBank
            ? const Color(0xFF0288D1)
            : isDigital
                ? const Color(0xFF8E24AA)
                : AppColors.success)
        : AppColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: account.isActive ? null : Border.all(color: AppColors.border),
        boxShadow: account.isActive
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 2))]
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
                    color: account.isActive ? iconColor.withValues(alpha: 0.1) : AppColors.surfaceDark,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getIcon(account.type), color: iconColor, size: 24),
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
                          color: account.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          account.type,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
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
                        color: account.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.isActive ? 'Activa' : 'Inactiva',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: account.isActive ? AppColors.success : AppColors.textSecondary,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 60, color: AppColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          const Text('No hay cuentas creadas', style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
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
