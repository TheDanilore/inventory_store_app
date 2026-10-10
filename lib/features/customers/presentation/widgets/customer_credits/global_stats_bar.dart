import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_kpi_metrics_bar.dart';

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

  String _compact(double v) =>
      v >= 1000
          ? 'S/ ${(v / 1000).toStringAsFixed(1)}K'
          : 'S/ ${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return AdminKpiMetricsBar(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      items: [
        AdminKpiItem(
          title: 'Cuentas Activas',
          value: '$activeAccounts',
          subtitle: suspendedAccounts > 0
              ? '$suspendedAccounts suspendidas'
              : '100% habilitadas',
          icon: Icons.people_alt_rounded,
          accentColor: AppColors.tealDark,
          gradientColors: const [Colors.white, Color(0xFFF0FDFA)],
          iconGradient: const [Color(0xFF0D9488), Color(0xFF0F766E)],
          borderColor: const Color(0xFF99F6E4),
          glowColor: const Color(0x2E0D9488),
        ),
        AdminKpiItem(
          title: 'Al Límite (Riesgo)',
          value: '$maxedOutAccounts',
          subtitle:
              maxedOutAccounts > 0 ? 'Requiere atención' : 'Líneas saludables',
          icon: Icons.warning_amber_rounded,
          accentColor:
              maxedOutAccounts > 0 ? AppColors.danger : AppColors.successDark,
          gradientColors: [
            Colors.white,
            maxedOutAccounts > 0
                ? const Color(0xFFFEF2F2)
                : const Color(0xFFECFDF5),
          ],
          iconGradient: maxedOutAccounts > 0
              ? const [Color(0xFFEF4444), Color(0xFFDC2626)]
              : const [Color(0xFF10B981), Color(0xFF059669)],
          borderColor: maxedOutAccounts > 0
              ? const Color(0xFFFECACA)
              : const Color(0xFFA7F3D0),
          glowColor: maxedOutAccounts > 0
              ? const Color(0x2EEF4444)
              : const Color(0x2E10B981),
          valueColor:
              maxedOutAccounts > 0 ? AppColors.danger : AppColors.textPrimary,
          isAlert: maxedOutAccounts > 0,
        ),
        AdminKpiItem(
          title: 'Total por Cobrar',
          value: _compact(totalDebt),
          subtitle: totalDebt > 0
              ? (accountsWithDebt > 0
                  ? '$accountsWithDebt clientes con saldo'
                  : 'Deuda total por cobrar')
              : 'Cuentas al día',
          icon: Icons.account_balance_wallet_rounded,
          accentColor:
              totalDebt > 0 ? AppColors.primary : AppColors.successDark,
          gradientColors: [
            Colors.white,
            totalDebt > 0
                ? const Color(0xFFF8FAFC)
                : const Color(0xFFECFDF5),
          ],
          iconGradient: totalDebt > 0
              ? const [Color(0xFF334155), Color(0xFF1E293B)]
              : const [Color(0xFF10B981), Color(0xFF059669)],
          borderColor:
              totalDebt > 0 ? const Color(0xFFE2E8F0) : const Color(0xFFA7F3D0),
          glowColor:
              totalDebt > 0 ? const Color(0x1F0F172A) : const Color(0x2E10B981),
          valueColor:
              totalDebt > 0 ? AppColors.textPrimary : AppColors.successDark,
        ),
      ],
    );
  }
}
