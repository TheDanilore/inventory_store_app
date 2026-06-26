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
            value: totalSpent,
            prefix: 'S/ ',
            label: 'Total',
            color: AppColors.success,
          ),
          const SizedBox(width: 10),
          _KpiCard(
            icon: Icons.shopping_bag_rounded,
            value: orderCount.toDouble(),
            prefix: '',
            label: 'Pedidos',
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          _KpiCard(
            icon: Icons.bar_chart_rounded,
            value: avgOrder,
            prefix: 'S/ ',
            label: 'Promedio',
            color: Colors.blue,
          ),
          const SizedBox(width: 10),
          _KpiCard(
            icon: Icons.stars_rounded,
            value: walletBalance.toDouble(),
            prefix: '',
            label: 'Monedas',
            color: AppColors.gold,
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final double value;
  final String prefix;
  final String label;
  final Color color;

  const _KpiCard({
    required this.icon,
    required this.value,
    required this.prefix,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = '$prefix${value.toStringAsFixed(0)}';

    return Expanded(
      child: Semantics(
        label: '$label: $displayValue',
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
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
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0, end: value),
                builder: (context, val, child) {
                  return Text(
                    '$prefix${val.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
