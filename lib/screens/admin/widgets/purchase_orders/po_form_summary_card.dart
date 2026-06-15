import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/admin/inventory_entry_form_screen.dart'; // For EntryItemUI
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class POFormSummaryCard extends StatelessWidget {
  final List<EntryItemUI> items;

  const POFormSummaryCard({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final double totalCost = items.fold(0, (sum, item) => sum + item.subtotal);
    final int totalUnits = items.fold(0, (sum, item) => sum + item.quantity.toInt());
    final int totalVariants = items.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Resumen de Orden',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'S/ ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                totalCost.toStringAsFixed(2),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: -1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SummaryStat(
                  label: 'Productos/Variantes',
                  value: totalVariants.toString(),
                ),
                Container(width: 1, height: 24, color: Colors.white24),
                _SummaryStat(
                  label: 'Unidades Totales',
                  value: totalUnits.toString(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
