import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts/financial_accounts_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts/financial_accounts_state.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/account_form_sheet.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/widgets/app_empty_state.dart';

class AccountsTab extends StatefulWidget {
  final bool showFab;
  final String? selectedAccountId;
  final ValueChanged<FinancialAccountEntity>? onSelectAccount;

  const AccountsTab({
    super.key,
    this.showFab = true,
    this.selectedAccountId,
    this.onSelectAccount,
  });

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
        final accounts = switch (state) {
          FinancialAccountsLoaded(:final accounts) => accounts,
          FinancialAccountSaving(:final previousAccounts) => previousAccounts,
          FinancialAccountSaved(:final accounts) => accounts,
          FinancialAccountSaveError(:final previousAccounts) =>
            previousAccounts,
          _ => <FinancialAccountEntity>[],
        };
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
                                                isSelected:
                                                    widget.selectedAccountId ==
                                                    entry.value.id,
                                                onTap: () {
                                                  if (widget.onSelectAccount !=
                                                      null) {
                                                    widget.onSelectAccount!(
                                                      entry.value,
                                                    );
                                                  } else {
                                                    AccountFormSheet.show(
                                                      context,
                                                      account: entry.value,
                                                    );
                                                  }
                                                },
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
                                                isSelected:
                                                    widget.selectedAccountId ==
                                                    entry.value.id,
                                                onTap: () {
                                                  if (widget.onSelectAccount !=
                                                      null) {
                                                    widget.onSelectAccount!(
                                                      entry.value,
                                                    );
                                                  } else {
                                                    AccountFormSheet.show(
                                                      context,
                                                      account: entry.value,
                                                    );
                                                  }
                                                },
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
            if (widget.showFab)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  heroTag: 'fab_accounts',
                  onPressed:
                      isLoading
                          ? null
                          : () {
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
    final currencyFmt = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -20,
            child: Icon(
              Icons.account_balance_wallet_rounded,
              size: 110,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Balance Global Disponible',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${activeAccounts.length} activas',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                currencyFmt.format(totalBalance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatefulWidget {
  final FinancialAccountEntity account;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _AccountCard({
    required this.account,
    this.isSelected = false,
    required this.onTap,
    required this.onEdit,
  });

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final account = widget.account;
    final isSelected = widget.isSelected;
    final isBank = account.type == 'BANCO';
    final isDigital = account.type == 'DIGITAL';
    final iconColor =
        account.isActive
            ? (isBank
                ? const Color(0xFF0288D1)
                : isDigital
                ? const Color(0xFF8E24AA)
                : AppColors.teal)
            : AppColors.textSecondary;
    final currencyFmt = NumberFormat.currency(locale: 'es_PE', symbol: 'S/ ');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? const Color(0xFFF0FDFA)
                  : (account.isActive ? Colors.white : AppColors.surface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                isSelected
                    ? AppColors.teal
                    : _isHovered
                    ? AppColors.teal.withValues(alpha: 0.35)
                    : (account.isActive
                        ? const Color(0xFFE2E8F0)
                        : AppColors.border),
            width: (isSelected || _isHovered) ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  isSelected
                      ? AppColors.teal.withValues(alpha: 0.1)
                      : Colors.black.withValues(
                        alpha: _isHovered ? 0.06 : 0.025,
                      ),
              blurRadius: (isSelected || _isHovered) ? 14 : 6,
              offset: Offset(0, (isSelected || _isHovered) ? 4 : 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                if (isSelected)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 3.5,
                      decoration: const BoxDecoration(
                        color: AppColors.teal,
                        borderRadius: BorderRadius.horizontal(
                          left: Radius.circular(14),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              account.isActive
                                  ? iconColor.withValues(alpha: 0.1)
                                  : AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getIcon(account.type),
                          color: iconColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              account.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color:
                                    account.isActive
                                        ? AppColors.textPrimary
                                        : AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  child: Text(
                                    account.type,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  const Text(
                                    '• Filtrando',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.tealDark,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currencyFmt.format(account.balance),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color:
                                  account.isActive
                                      ? AppColors.textPrimary
                                      : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                account.isActive ? 'Activa' : 'Inactiva',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      account.isActive
                                          ? AppColors.teal
                                          : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 14,
                                  color: AppColors.textMuted,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 24,
                                  minHeight: 24,
                                ),
                                tooltip: 'Editar cuenta',
                                onPressed: widget.onEdit,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
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
