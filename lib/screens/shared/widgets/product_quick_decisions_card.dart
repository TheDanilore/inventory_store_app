// ─── COMPONENTE NUEVO: DECISIONES RÁPIDAS ────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class ProductQuickDecisionsCard extends StatelessWidget {
  final int totalSold;
  final double reinvestmentNeeded;
  final double inventoryValue;

  const ProductQuickDecisionsCard({
    super.key,
    required this.totalSold,
    required this.reinvestmentNeeded,
    required this.inventoryValue,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = totalSold > 0 || inventoryValue > 0;
    if (!hasData) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        border: Border.all(color: const Color(0xFF86EFAC), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
            ],
          ),
          const SizedBox(height: 12),
          if (totalSold > 0)
            Text(
              'Has vendido $totalSold unidades en total.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF15803D),
                fontWeight: FontWeight.w600,
              ),
            ),
          if (totalSold > 0) const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              children: [
                // Valor de inventario actual (siempre visible si hay stock)
                if (inventoryValue > 0) ...[
                  _DecisionRow(
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.primary,
                    label: 'Capital en inventario',
                    value: 'S/ ${inventoryValue.toStringAsFixed(2)}',
                    subtitle: 'Valor del stock actual al costo.',
                  ),
                ],
                // Fondo de reposición (solo si hay ventas históricas)
                if (totalSold > 0 && reinvestmentNeeded > 0) ...[
                  if (inventoryValue > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: Color(0xFFBBF7D0)),
                    ),
                  _DecisionRow(
                    icon: Icons.inventory_2_outlined,
                    color: AppColors.amberDark,
                    label: 'Fondo de reposición',
                    value: 'S/ ${reinvestmentNeeded.toStringAsFixed(2)}',
                    subtitle: 'Ideal para reinvertir en stock.',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DecisionRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String? subtitle;

  const _DecisionRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.subtitle,
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
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
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
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }
}
