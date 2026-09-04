import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';

class KardexKpiStrip extends StatelessWidget {
  final List<KardexMovementEntity> movements;
  final int totalCount;

  const KardexKpiStrip({
    super.key,
    required this.movements,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    // Cálculo en memoria de métricas del lote/conjunto visible
    double totalEntries = 0;
    double totalExits = 0;
    double totalCostVolume = 0;

    for (final m in movements) {
      final upper = m.type.toUpperCase();
      final isEntry = upper.contains('INGRESO') || upper.contains('DEVOLUCIÓN');
      if (isEntry) {
        totalEntries += m.quantity.abs();
      } else {
        totalExits += m.quantity.abs();
      }
      totalCostVolume += (m.quantity.abs() * m.unitCost);
    }

    final netFlow = totalEntries - totalExits;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final isTablet = constraints.maxWidth >= 600 && !isDesktop;

        final items = [
          _KpiItem(
            label: 'Total Operaciones',
            value: '$totalCount',
            subtext: '${movements.length} en página actual',
            icon: Icons.receipt_long_rounded,
            color: AppColors.primary,
            bgColor: AppColors.primary.withValues(alpha: 0.07),
          ),
          _KpiItem(
            label: 'Flujo de Entrada',
            value: '+${totalEntries.toInt()} uds.',
            subtext: 'Ingresos y retornos',
            icon: Icons.arrow_downward_rounded,
            color: AppColors.success,
            bgColor: AppColors.success.withValues(alpha: 0.08),
          ),
          _KpiItem(
            label: 'Flujo de Salida',
            value: '-${totalExits.toInt()} uds.',
            subtext: 'Ventas y mermas',
            icon: Icons.arrow_upward_rounded,
            color: AppColors.danger,
            bgColor: AppColors.danger.withValues(alpha: 0.08),
          ),
          _KpiItem(
            label: 'Variación Neta',
            value: '${netFlow >= 0 ? '+' : ''}${netFlow.toInt()} uds.',
            subtext: 'Volumen S/ ${totalCostVolume.toStringAsFixed(2)}',
            icon: Icons.balance_rounded,
            color: netFlow >= 0 ? AppColors.primary : AppColors.warning,
            bgColor: (netFlow >= 0 ? AppColors.primary : AppColors.warning)
                .withValues(alpha: 0.08),
          ),
        ];

        if (isDesktop) {
          return Row(
            children: items
                .map(
                  (item) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: item,
                    ),
                  ),
                )
                .toList(),
          );
        }

        if (isTablet) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => SizedBox(
                    width: (constraints.maxWidth - 24) / 2,
                    child: item,
                  ),
                )
                .toList(),
          );
        }

        // Móvil: Scroll horizontal compacto con tarjetas satinadas
        return SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return SizedBox(width: 170, child: items[index]);
            },
          ),
        );
      },
    );
  }
}

class _KpiItem extends StatelessWidget {
  final String label;
  final String value;
  final String subtext;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _KpiItem({
    required this.label,
    required this.value,
    required this.subtext,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow(opacity: 0.02),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: color == AppColors.primary
                        ? AppColors.textPrimary
                        : color,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  subtext,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
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
