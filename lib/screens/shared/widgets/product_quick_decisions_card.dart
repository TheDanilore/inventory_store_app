// ─── COMPONENTE: DECISIONES RÁPIDAS ──────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class ProductQuickDecisionsCard extends StatelessWidget {
  final int totalSold;
  final double reinvestmentNeeded;
  final double inventoryValue;
  final double totalRevenue;

  const ProductQuickDecisionsCard({
    super.key,
    required this.totalSold,
    required this.reinvestmentNeeded,
    required this.inventoryValue,
    required this.totalRevenue,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = totalSold > 0 || inventoryValue > 0;
    if (!hasData) return const SizedBox.shrink();

    // Ganancia realizada = ingresos - costo de lo vendido (reinvestment)
    final double realizedProfit = totalRevenue - reinvestmentNeeded;
    // Capital total = lo que tengo en stock + lo que ya cobré
    final double totalCapital = inventoryValue + totalRevenue;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Encabezado ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Color(0xFF166534),
                    size: 16,
                  ),
                ),
                const SizedBox(width: 9),
                const Text(
                  'Decisiones rápidas',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF166534),
                  ),
                ),
                const Spacer(),
                if (totalSold > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$totalSold uds. vendidas',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF166534),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Fila de totales resaltados ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                // Capital en inventario
                _TotalHighlight(
                  label: 'En inventario',
                  value: 'S/ ${inventoryValue.toStringAsFixed(2)}',
                  icon: Icons.inventory_2_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                // Ingresos por ventas
                _TotalHighlight(
                  label: 'Ingresos ventas',
                  value: 'S/ ${totalRevenue.toStringAsFixed(2)}',
                  icon: Icons.trending_up_rounded,
                  color: const Color(0xFF059669),
                ),
              ],
            ),
          ),

          // ── Detalle ────────────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              children: [
                if (reinvestmentNeeded > 0) ...[
                  _DecisionRow(
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.amberDark,
                    label: 'Fondo de reposición',
                    value: 'S/ ${reinvestmentNeeded.toStringAsFixed(2)}',
                    subtitle: 'Para reponer el stock vendido al costo.',
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(height: 1, color: Color(0xFFBBF7D0)),
                  ),
                ],
                _DecisionRow(
                  icon: Icons.savings_rounded,
                  color:
                      realizedProfit >= 0
                          ? const Color(0xFF059669)
                          : AppColors.danger,
                  label: 'Ganancia realizada',
                  value:
                      '${realizedProfit >= 0 ? '+' : ''}S/ ${realizedProfit.toStringAsFixed(2)}',
                  subtitle: 'Ingresos totales menos costo de lo vendido.',
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, color: Color(0xFFBBF7D0)),
                ),
                // Total general
                _DecisionRow(
                  icon: Icons.account_balance_rounded,
                  color: const Color(0xFF166534),
                  label: 'Capital total generado',
                  value: 'S/ ${totalCapital.toStringAsFixed(2)}',
                  subtitle: 'Inventario actual + ingresos acumulados.',
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tarjeta de total destacado ────────────────────────────────────────────────

class _TotalHighlight extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _TotalHighlight({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: color.withValues(alpha: 0.7),
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: color,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Fila de detalle ───────────────────────────────────────────────────────────

class _DecisionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? subtitle;
  final bool isBold;

  const _DecisionRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.subtitle,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: isBold ? color : AppColors.textSecondary,
                  fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
            ],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 15 : 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}
