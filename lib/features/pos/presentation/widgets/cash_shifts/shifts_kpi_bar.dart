import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_state.dart';

/// Barra de KPI cards para la pantalla de turnos de caja.
class ShiftsKpiBar extends StatelessWidget {
  final CashShiftsState state;

  const ShiftsKpiBar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final total = state.totalCount > 0 ? state.totalCount : state.shifts.length;
    final openCount =
        state.totalOpenCount > 0
            ? state.totalOpenCount
            : state.shifts
                .where((s) => s.status == CashShiftStatus.open)
                .length;
    final closedCount =
        state.totalClosedCount > 0
            ? state.totalClosedCount
            : state.shifts
                .where((s) => s.status == CashShiftStatus.closed)
                .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          if (isNarrow) {
            return Row(
              children: [
                Expanded(
                  child: _KpiCard(
                    title: 'Registros',
                    value: '$total',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiCard(
                    title: 'Abiertos',
                    value: '$openCount',
                    icon: Icons.play_circle_fill_rounded,
                    color: AppColors.success,
                    isPulsing: openCount > 0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _KpiCard(
                    title: 'Cerrados',
                    value: '$closedCount',
                    icon: Icons.check_circle_rounded,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(
                child: _KpiCard(
                  title: 'Total Registros',
                  value: '$total turnos',
                  icon: Icons.receipt_long_rounded,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  title: 'Turnos Abiertos',
                  value: '$openCount en curso',
                  icon: Icons.play_circle_fill_rounded,
                  color: AppColors.success,
                  isPulsing: openCount > 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KpiCard(
                  title: 'Turnos Cerrados',
                  value: '$closedCount completados',
                  icon: Icons.check_circle_rounded,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isPulsing;

  const _KpiCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.isPulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: 0.4),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
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
