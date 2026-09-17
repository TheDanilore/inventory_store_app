import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class GlobalStatsBar extends StatelessWidget {
  final double totalDebt;
  final int activeAccounts;
  final int suspendedAccounts;
  final int maxedOutAccounts;
  final int accountsWithDebt;

  const GlobalStatsBar({
    super.key,
    required this.totalDebt,
    required this.activeAccounts,
    required this.suspendedAccounts,
    required this.maxedOutAccounts,
    this.accountsWithDebt = 0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 950;
        final isTablet =
            constraints.maxWidth >= 600 && constraints.maxWidth < 950;

        final cards = [
          _BentoMetricCard(
            title: 'Deuda Total',
            value: 'S/ ${totalDebt.toStringAsFixed(2)}',
            subtitle:
                accountsWithDebt > 0
                    ? '$accountsWithDebt clientes con saldo'
                    : 'Sin deudas pendientes',
            icon: Icons.account_balance_wallet_rounded,
            accentColor:
                totalDebt > 0 ? const Color(0xFFDC2626) : AppColors.success,
            iconBgColor:
                totalDebt > 0
                    ? const Color(0xFFFEF2F2)
                    : const Color(0xFFF0FDF4),
          ),
          _BentoMetricCard(
            title: 'Líneas Activas',
            value: '$activeAccounts',
            subtitle: 'Habilitadas para compras',
            icon: Icons.credit_card_rounded,
            accentColor: const Color(0xFF0D9488),
            iconBgColor: const Color(0xFFF0FDFA),
          ),
          _BentoMetricCard(
            title: 'Al Límite',
            value: '$maxedOutAccounts',
            subtitle: 'Cupo >= 80% utilizado',
            icon: Icons.warning_amber_rounded,
            accentColor:
                maxedOutAccounts > 0
                    ? const Color(0xFFEA580C)
                    : AppColors.textMuted,
            iconBgColor:
                maxedOutAccounts > 0
                    ? const Color(0xFFFFFBEB)
                    : const Color(0xFFF8FAFC),
          ),
          _BentoMetricCard(
            title: 'Suspendidas',
            value: '$suspendedAccounts',
            subtitle: 'Bloqueadas temporalmente',
            icon: Icons.block_rounded,
            accentColor:
                suspendedAccounts > 0
                    ? const Color(0xFFE11D48)
                    : AppColors.textMuted,
            iconBgColor:
                suspendedAccounts > 0
                    ? const Color(0xFFFFF1F2)
                    : const Color(0xFFF8FAFC),
          ),
        ];

        if (isDesktop) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                for (int i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: cards[i]),
                ],
              ],
            ),
          );
        }

        if (isTablet) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: cards[0]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[1]),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: cards[2]),
                    const SizedBox(width: 12),
                    Expanded(child: cards[3]),
                  ],
                ),
              ],
            ),
          );
        }

        // Mobile: 2x2 grid with compact height
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[1]),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: cards[2]),
                  const SizedBox(width: 10),
                  Expanded(child: cards[3]),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BentoMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final Color iconBgColor;

  const _BentoMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: accentColor, size: 17),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: accentColor,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
