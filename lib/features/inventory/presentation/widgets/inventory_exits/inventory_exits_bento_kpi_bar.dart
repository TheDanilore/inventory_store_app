import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/admin_kpi_metrics_bar.dart';

class InventoryExitsBentoKpiBar extends StatelessWidget {
  final int count;
  final int totalCount;
  final double totalCost;
  final int totalUnits;
  final String warehouseName;
  final bool isDesktop;

  const InventoryExitsBentoKpiBar({
    super.key,
    required this.count,
    required this.totalCount,
    required this.totalCost,
    required this.totalUnits,
    required this.warehouseName,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    final isFilteredByWarehouse =
        warehouseName != 'Todos' && warehouseName != 'TODOS';

    return RepaintBoundary(
      child: AdminKpiMetricsBar(
        isDesktop: isDesktop,
        padding: EdgeInsets.zero,
        items: [
          AdminKpiItem(
            title: 'Total Salidas',
            value: totalCount > 0 ? '$totalCount' : '$count',
            subtitle: isFilteredByWarehouse ? 'En $warehouseName' : 'Registradas',
            icon: Icons.outbox_rounded,
            accentColor: AppColors.primary,
            gradientColors: const [Colors.white, Color(0xFFF8FAFC)],
            iconGradient: const [Color(0xFF334155), Color(0xFF1E293B)],
            borderColor: const Color(0xFFE2E8F0),
            glowColor: const Color(0x1F0F172A),
          ),
          AdminKpiItem(
            title: 'Costo Total Salidas',
            value: 'S/ ${totalCost.toStringAsFixed(2)}',
            subtitle: 'Costo acumulado',
            icon: Icons.payments_rounded,
            accentColor: AppColors.dangerDark,
            gradientColors: const [Colors.white, Color(0xFFFEF2F2)],
            iconGradient: const [Color(0xFFEF4444), Color(0xFFDC2626)],
            borderColor: const Color(0xFFFECACA),
            glowColor: const Color(0x2EEF4444),
            valueColor: AppColors.dangerDark,
            isAlert: true,
          ),
          AdminKpiItem(
            title: 'Unidades Despachadas',
            value: '$totalUnits uds.',
            subtitle: 'Despachadas',
            icon: Icons.inventory_2_rounded,
            accentColor: AppColors.tealDark,
            gradientColors: const [Colors.white, Color(0xFFF0FDFA)],
            iconGradient: const [Color(0xFF0D9488), Color(0xFF0F766E)],
            borderColor: const Color(0xFF99F6E4),
            glowColor: const Color(0x2E0D9488),
          ),
        ],
      ),
    );
  }
}

