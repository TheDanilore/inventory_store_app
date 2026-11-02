import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_kpi_metrics_bar.dart';

/// Bento KPI Bar para Órdenes de Compra (Estilo Stripe / Linear)
class PurchaseOrdersBentoKpiBar extends StatelessWidget {
  final int orderCount;
  final int totalRecords;
  final double totalAmount;
  final int pendingCount;
  final double totalDebt;
  final bool isDesktop;

  const PurchaseOrdersBentoKpiBar({
    super.key,
    required this.orderCount,
    required this.totalRecords,
    required this.totalAmount,
    required this.pendingCount,
    required this.totalDebt,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return AdminKpiMetricsBar(
      isDesktop: isDesktop,
      padding: EdgeInsets.zero,
      items: [
        AdminKpiItem(
          title: 'Total Órdenes',
          value: totalRecords > 0 ? '$totalRecords' : '$orderCount',
          subtitle: 'Registradas',
          icon: Icons.receipt_long_rounded,
          accentColor: AppColors.tealDark,
          gradientColors: const [Colors.white, Color(0xFFF0FDFA)],
          iconGradient: const [Color(0xFF0D9488), Color(0xFF0F766E)],
          borderColor: const Color(0xFF99F6E4),
          glowColor: const Color(0x2E0D9488),
        ),
        AdminKpiItem(
          title: 'Monto Compras',
          value: 'S/ ${totalAmount.toStringAsFixed(2)}',
          subtitle: 'Acumulado',
          icon: Icons.payments_rounded,
          accentColor: AppColors.successDark,
          gradientColors: const [Colors.white, Color(0xFFECFDF5)],
          iconGradient: const [Color(0xFF10B981), Color(0xFF059669)],
          borderColor: const Color(0xFFA7F3D0),
          glowColor: const Color(0x2E10B981),
        ),
        AdminKpiItem(
          title: 'Por Recibir / Pend.',
          value: '$pendingCount',
          subtitle: pendingCount > 0 ? 'Pendientes' : 'Al día',
          icon:
              pendingCount > 0
                  ? Icons.pending_actions_rounded
                  : Icons.check_circle_outline_rounded,
          accentColor:
              pendingCount > 0 ? AppColors.warningDark : AppColors.successDark,
          gradientColors: [
            Colors.white,
            pendingCount > 0
                ? const Color(0xFFFFFBEB)
                : const Color(0xFFECFDF5),
          ],
          iconGradient:
              pendingCount > 0
                  ? const [Color(0xFFF59E0B), Color(0xFFD97706)]
                  : const [Color(0xFF10B981), Color(0xFF059669)],
          borderColor:
              pendingCount > 0
                  ? const Color(0xFFFDE68A)
                  : const Color(0xFFA7F3D0),
          glowColor:
              pendingCount > 0
                  ? const Color(0x2EF59E0B)
                  : const Color(0x2E10B981),
        ),
        AdminKpiItem(
          title: 'Saldo por Pagar',
          value: 'S/ ${totalDebt.toStringAsFixed(2)}',
          subtitle: totalDebt > 0 ? 'Cuentas pendientes' : 'Sin deudas',
          icon: Icons.account_balance_wallet_rounded,
          accentColor: totalDebt > 0 ? AppColors.accent : AppColors.tealDark,
          gradientColors: [
            Colors.white,
            totalDebt > 0 ? const Color(0xFFFFF1F2) : const Color(0xFFF0FDFA),
          ],
          iconGradient:
              totalDebt > 0
                  ? const [Color(0xFFF43F5E), Color(0xFFE11D48)]
                  : const [Color(0xFF0D9488), Color(0xFF0F766E)],
          borderColor:
              totalDebt > 0 ? const Color(0xFFFECDD3) : const Color(0xFF99F6E4),
          glowColor:
              totalDebt > 0 ? const Color(0x2EF43F5E) : const Color(0x2E0D9488),
          valueColor: totalDebt > 0 ? AppColors.accent : AppColors.textPrimary,
        ),
      ],
    );
  }
}
