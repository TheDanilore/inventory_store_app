import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_kpi_metrics_bar.dart';

/// Bento KPI Metrics Bar para el historial de entradas de inventario.
class InventoryEntriesBentoKpiBar extends StatelessWidget {
  final int count;
  final int totalCount;
  final double totalAmount;
  final String warehouseName;
  final bool isDesktop;

  const InventoryEntriesBentoKpiBar({
    super.key,
    required this.count,
    required this.totalCount,
    required this.totalAmount,
    required this.warehouseName,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return AdminKpiMetricsBar(
      isDesktop: isDesktop,
      padding: EdgeInsets.zero,
      items: [
        AdminKpiItem(
          title: 'Total Entradas',
          value: totalCount > 0 ? '$totalCount' : '$count',
          subtitle: 'Registradas',
          icon: Icons.move_to_inbox_rounded,
          accentColor: AppColors.tealDark,
          gradientColors: const [Colors.white, Color(0xFFF0FDFA)],
          iconGradient: const [Color(0xFF0D9488), Color(0xFF0F766E)],
          borderColor: const Color(0xFF99F6E4),
          glowColor: const Color(0x2E0D9488),
        ),
        AdminKpiItem(
          title: 'Inversión Total',
          value: 'S/ ${totalAmount.toStringAsFixed(2)}',
          subtitle: 'Acumulada',
          icon: Icons.payments_rounded,
          accentColor: AppColors.successDark,
          gradientColors: const [Colors.white, Color(0xFFECFDF5)],
          iconGradient: const [Color(0xFF10B981), Color(0xFF059669)],
          borderColor: const Color(0xFFA7F3D0),
          glowColor: const Color(0x2E10B981),
        ),
        AdminKpiItem(
          title: 'Almacén Destino',
          value:
              (warehouseName == 'TODOS' || warehouseName == 'Todos')
                  ? 'Todos'
                  : warehouseName,
          subtitle: 'Filtro aplicado',
          icon: Icons.storefront_rounded,
          accentColor: AppColors.warningDark,
          gradientColors: const [Colors.white, Color(0xFFFFFBEB)],
          iconGradient: const [Color(0xFFF59E0B), Color(0xFFD97706)],
          borderColor: const Color(0xFFFDE68A),
          glowColor: const Color(0x2EF59E0B),
        ),
      ],
    );
  }
}
