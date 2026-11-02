import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/widgets/admin_kpi_metrics_bar.dart';

/// Bento KPI Bar para Gestión de Pedidos (Estilo Stripe / Linear)
class OrdersBentoKpiBar extends StatelessWidget {
  final int pageOrdersCount;
  final int totalRecords;
  final double pageTotalAmount;
  final int pendingCount;
  final double pendingDebt;
  final bool isWide;

  const OrdersBentoKpiBar({
    super.key,
    required this.pageOrdersCount,
    required this.totalRecords,
    required this.pageTotalAmount,
    required this.pendingCount,
    required this.pendingDebt,
    required this.isWide,
  });

  @override
  Widget build(BuildContext context) {
    return AdminKpiMetricsBar(
      isDesktop: isWide,
      padding: EdgeInsets.zero,
      items: [
        AdminKpiItem(
          title: 'Total Pedidos',
          value: '$totalRecords',
          subtitle: 'Registrados',
          icon: Icons.receipt_long_rounded,
          gradientColors: const [Colors.white, Color(0xFFF0FDFA)],
          iconGradient: const [Color(0xFF0D9488), Color(0xFF0F766E)],
          borderColor: const Color(0xFF99F6E4),
          accentColor: const Color(0xFF0D9488),
          glowColor: const Color(0x2E0D9488),
        ),
        AdminKpiItem(
          title: 'Total Facturado',
          value: 'S/ ${pageTotalAmount.toStringAsFixed(2)}',
          subtitle: 'Facturado',
          icon: Icons.payments_rounded,
          gradientColors: const [Colors.white, Color(0xFFECFDF5)],
          iconGradient: const [Color(0xFF10B981), Color(0xFF059669)],
          borderColor: const Color(0xFFA7F3D0),
          accentColor: const Color(0xFF059669),
          glowColor: const Color(0x2E10B981),
        ),
        AdminKpiItem(
          title: pendingDebt > 0 ? 'Por Cobrar' : 'Pendientes',
          value:
              pendingDebt > 0
                  ? 'S/ ${pendingDebt.toStringAsFixed(2)}'
                  : '$pendingCount',
          subtitle: pendingDebt > 0 ? 'Créditos' : 'Borradores',
          icon:
              pendingDebt > 0
                  ? Icons.credit_card_rounded
                  : Icons.pending_actions_rounded,
          gradientColors: const [Colors.white, Color(0xFFFFFBEB)],
          iconGradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
          borderColor: const Color(0xFFFDE68A),
          accentColor: const Color(0xFFD97706),
          glowColor: const Color(0x2EF59E0B),
        ),
      ],
    );
  }
}
