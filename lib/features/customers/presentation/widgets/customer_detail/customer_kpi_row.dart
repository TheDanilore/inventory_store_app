import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class CustomerKpiRow extends StatelessWidget {
  final double totalSpent;
  final int orderCount;
  final double avgOrder;
  final double walletBalance;
  final bool isLoyaltyEnabled;

  const CustomerKpiRow({
    super.key,
    required this.totalSpent,
    required this.orderCount,
    required this.avgOrder,
    required this.walletBalance,
    required this.isLoyaltyEnabled,
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
          if (isLoyaltyEnabled) ...[
            const SizedBox(width: 10),
            _KpiCard(
              icon: Icons.stars_rounded,
              value: walletBalance.toDouble(),
              prefix: '',
              label: 'Monedas',
              color: AppColors.gold,
            ),
          ],
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
    final decimals = prefix == 'S/ ' ? 2 : 0;
    final displayValue = '$prefix${value.toStringAsFixed(decimals)}';

    return Expanded(
      child: Semantics(
        label: '$label: $displayValue',
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0, end: value),
                builder: (context, val, child) {
                  return Text(
                    '$prefix${val.toStringAsFixed(decimals)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
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
