import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class MovementsDashboardSummary extends StatelessWidget {
  final double totalIncome;
  final double totalExpense;

  const MovementsDashboardSummary({
    super.key,
    required this.totalIncome,
    required this.totalExpense,
  });

  @override
  Widget build(BuildContext context) {
    final balance = totalIncome - totalExpense;
    final incomeFlex = (totalIncome * 100).round().clamp(1, 1000000000);
    final expenseFlex = (totalExpense * 100).round().clamp(1, 1000000000);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 6,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DashItem(
                  title: 'Ingresos',
                  amount: totalIncome,
                  color: AppColors.tealDark,
                  icon: Icons.arrow_upward_rounded,
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _DashItem(
                  title: 'Egresos',
                  amount: totalExpense,
                  color: AppColors.danger,
                  icon: Icons.arrow_downward_rounded,
                ),
              ),
              Container(width: 1, height: 36, color: const Color(0xFFE2E8F0)),
              Expanded(
                child: _DashItem(
                  title: 'Flujo Neto',
                  amount: balance,
                  color: balance >= 0 ? AppColors.tealDark : AppColors.danger,
                  icon: Icons.account_balance_wallet_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (totalIncome > 0 || totalExpense > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Row(
                children: [
                  if (totalIncome > 0)
                    Expanded(
                      flex: incomeFlex,
                      child: Container(height: 4, color: AppColors.teal),
                    ),
                  if (totalExpense > 0)
                    Expanded(
                      flex: expenseFlex,
                      child: Container(height: 4, color: AppColors.danger),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DashItem extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;

  static final _currencyFormat = NumberFormat('#,##0.00', 'es_PE');

  const _DashItem({
    required this.title,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 12, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'S/ ${_currencyFormat.format(amount.abs())}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14.5,
            color: color,
            letterSpacing: -0.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
