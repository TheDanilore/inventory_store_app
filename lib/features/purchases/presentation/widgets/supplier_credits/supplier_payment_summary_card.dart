import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class SupplierPaymentSummaryCard extends StatelessWidget {
  final double amountToPay;
  final double currentDebt;

  const SupplierPaymentSummaryCard({
    super.key,
    required this.amountToPay,
    required this.currentDebt,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (currentDebt - amountToPay).clamp(0.0, double.infinity);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resumen de la operación',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pago total:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'S/ ${amountToPay.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Deuda restante:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'S/ ${remaining.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class QuickAmountChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isTotalChip;
  final VoidCallback onTap;

  const QuickAmountChip({
    super.key,
    required this.label,
    required this.isSelected,
    this.isTotalChip = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? (isTotalChip ? AppColors.danger : AppColors.teal)
                  : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
