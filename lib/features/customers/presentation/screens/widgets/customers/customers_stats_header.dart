import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/customers/presentation/providers/customers_provider.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class CustomersStatsHeader extends StatelessWidget {
  final CustomersProvider provider;

  const CustomersStatsHeader({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF2A2A4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatItem(
            value: provider.totalCustomersCount.toDouble(),
            label: 'Total',
            icon: Icons.people_alt_rounded,
          ),
          _VerticalDivider(),
          _StatItem(
            value: provider.activeCustomersCount.toDouble(),
            label: 'Activos',
            icon: Icons.check_circle_rounded,
            valueColor: Colors.greenAccent,
          ),
          _VerticalDivider(),
          _StatItem(
            value: provider.totalRevenue,
            label: 'Ingresos',
            icon: Icons.attach_money_rounded,
            valueColor: Colors.amberAccent,
            isCurrency: true,
          ),
          _VerticalDivider(),
          _StatItem(
            value: provider.totalDebt,
            label: 'Por cobrar',
            icon: Icons.credit_card_rounded,
            valueColor: Colors.redAccent.shade100,
            isCurrency: true,
          ),
        ],
      ),
    );
  }

  static String _compact(double v, bool isCurrency) {
    if (v >= 1000000) return '${isCurrency ? 'S/ ' : ''}${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${isCurrency ? 'S/ ' : ''}${(v / 1000).toStringAsFixed(1)}K';
    return isCurrency ? 'S/ ${v.toStringAsFixed(0)}' : v.toStringAsFixed(0);
  }
}

class _StatItem extends StatelessWidget {
  final double value;
  final String label;
  final IconData icon;
  final Color? valueColor;
  final bool isCurrency;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    this.valueColor,
    this.isCurrency = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: 0, end: value),
            builder: (context, val, child) {
              return Text(
                CustomersStatsHeader._compact(val, isCurrency),
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withValues(alpha: 0.25),
    );
  }
}
