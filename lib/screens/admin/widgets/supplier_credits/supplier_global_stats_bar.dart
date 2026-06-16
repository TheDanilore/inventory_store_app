import 'package:flutter/material.dart';

class SupplierGlobalStatsBar extends StatelessWidget {
  final double totalDebt;
  final int activeAccounts;
  final int suspendedAccounts;
  final int maxedOutAccounts;

  const SupplierGlobalStatsBar({
    super.key,
    required this.totalDebt,
    required this.activeAccounts,
    required this.suspendedAccounts,
    required this.maxedOutAccounts,
  });

  String _compact(double v) =>
      v >= 1000
          ? 'S/ ${(v / 1000).toStringAsFixed(1)}K'
          : 'S/ ${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatItem(
            icon: Icons.storefront_rounded,
            value: '$activeAccounts',
            label: 'Activos',
          ),
          Container(height: 36, width: 1, color: Colors.white24),
          _StatItem(
            icon: Icons.warning_amber_rounded,
            value: '$maxedOutAccounts',
            label: 'Al límite',
            valueColor:
                maxedOutAccounts > 0 ? Colors.orange.shade200 : Colors.white,
          ),
          Container(height: 36, width: 1, color: Colors.white24),
          _StatItem(
            icon: Icons.account_balance_rounded,
            value: _compact(totalDebt),
            label: 'Por Pagar',
            valueColor: totalDebt > 0 ? Colors.orange.shade200 : Colors.white,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? valueColor;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
