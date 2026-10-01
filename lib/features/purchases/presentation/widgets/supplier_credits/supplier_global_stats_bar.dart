import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class SupplierGlobalStatsBar extends StatelessWidget {
  final double totalDebt;
  final int activeAccounts;
  final int suspendedAccounts;
  final int maxedOutAccounts;

  const SupplierGlobalStatsBar({
    super.key,
    required this.totalDebt,
    required this.activeAccounts,
    required this.suspendedAccounts,
    required this.maxedOutAccounts,
  });

  String _compact(double v) =>
      v >= 1000
          ? 'S/ ${(v / 1000).toStringAsFixed(1)}K'
          : 'S/ ${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 800;

    final cards = [
      _BentoMetricCard(
        title: 'Cuentas Activas',
        value: '$activeAccounts',
        subtitle:
            suspendedAccounts > 0
                ? '$suspendedAccounts suspendidas'
                : '100% habilitadas',
        icon: Icons.storefront_rounded,
        iconBgColor: AppColors.tealLight,
        iconColor: AppColors.tealDark,
      ),
      _BentoMetricCard(
        title: 'Al Límite (Riesgo)',
        value: '$maxedOutAccounts',
        subtitle:
            maxedOutAccounts > 0 ? 'Requiere atención' : 'Líneas saludables',
        icon: Icons.warning_amber_rounded,
        iconBgColor:
            maxedOutAccounts > 0 ? AppColors.dangerLight : AppColors.successLight,
        iconColor:
            maxedOutAccounts > 0 ? AppColors.danger : AppColors.successDark,
        valueColor:
            maxedOutAccounts > 0 ? AppColors.danger : AppColors.textPrimary,
      ),
      _BentoMetricCard(
        title: 'Total por Pagar',
        value: _compact(totalDebt),
        subtitle:
            totalDebt > 0
                ? 'Deuda total a proveedores'
                : 'Cuentas al día',
        icon: Icons.account_balance_rounded,
        iconBgColor: AppColors.primaryLight,
        iconColor: AppColors.primary,
        valueColor:
            totalDebt > 0 ? AppColors.textPrimary : AppColors.successDark,
      ),
    ];

    if (isDesktop) {
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
            const SizedBox(width: 12),
            Expanded(child: cards[2]),
          ],
        ),
      );
    }

    // Móvil / Tablet: Scroll horizontal sutil o columna compacta
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: cards.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, index) => SizedBox(width: 220, child: cards[index]),
      ),
    );
  }
}

class _BentoMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final Color? valueColor;

  const _BentoMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: valueColor ?? AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
