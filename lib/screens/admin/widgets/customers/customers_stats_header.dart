import 'package:flutter/material.dart';
import 'package:inventory_store_app/providers/admin/customers_provider.dart';

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
          colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
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
            value: '${provider.totalCustomersCount}',
            label: 'Total',
            icon: Icons.people_alt_rounded,
          ),
          _VerticalDivider(),
          _StatItem(
            value: '${provider.activeCustomersCount}',
            label: 'Activos',
            icon: Icons.check_circle_rounded,
            valueColor: Colors.greenAccent,
          ),
          _VerticalDivider(),
          _StatItem(
            value: _compact(provider.totalRevenue),
            label: 'Ingresos',
            icon: Icons.attach_money_rounded,
            valueColor: Colors.amberAccent,
          ),
          _VerticalDivider(),
          _StatItem(
            value: _compact(provider.totalDebt),
            label: 'Por cobrar',
            icon: Icons.credit_card_rounded,
            valueColor: Colors.redAccent.shade100,
          ),
        ],
      ),
    );
  }

  String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color? valueColor;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 10,
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
