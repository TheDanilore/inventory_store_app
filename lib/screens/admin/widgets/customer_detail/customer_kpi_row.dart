import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class CustomerKpiRow extends StatelessWidget {
  final double totalSpent;
  final int orderCount;
  final double avgOrder;
  final int walletBalance;

  const CustomerKpiRow({
    super.key,
    required this.totalSpent,
    required this.orderCount,
    required this.avgOrder,
    required this.walletBalance,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _KpiCard(
            icon: Icons.attach_money_rounded,
            value: 'S/ ${totalSpent.toStringAsFixed(0)}',
            label: 'Total',
            color: AppColors.success,
          ),
          const SizedBox(width: 10),
          _KpiCard(
            icon: Icons.shopping_bag_rounded,
            value: '$orderCount',
            label: 'Pedidos',
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          _KpiCard(
            icon: Icons.bar_chart_rounded,
            value: 'S/ ${avgOrder.toStringAsFixed(0)}',
            label: 'Promedio',
            color: Colors.purple,
          ),
          const SizedBox(width: 10),
          _KpiCard(
            icon: Icons.stars_rounded,
            value: '$walletBalance',
            label: 'Monedas',
            color: Colors.amber.shade700,
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _KpiCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
