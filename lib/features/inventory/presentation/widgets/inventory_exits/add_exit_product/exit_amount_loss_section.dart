import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/add_exit_product/exit_sheet_helpers.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/exit_quantity_stepper.dart';

class ExitAmountLossSection extends StatelessWidget {
  final String productId;
  final String? variantId;
  final String batchKey;
  final double unitCost;
  final double quantity;
  final double maxAvailable;
  final ValueChanged<double> onQuantityChanged;

  const ExitAmountLossSection({
    super.key,
    required this.productId,
    required this.variantId,
    required this.batchKey,
    required this.unitCost,
    required this.quantity,
    required this.maxAvailable,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final costField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ExitFieldLabel('Costo unitario'),
        const SizedBox(height: 8),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unitCost == 0 ? AppColors.warning : AppColors.border,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'S/ ${unitCost.toStringAsFixed(2)}',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
        if (unitCost == 0)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              'Sin costo registrado',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.warning,
              ),
            ),
          ),
      ],
    );

    final qtyField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ExitFieldLabel('Cantidad a retirar'),
        const SizedBox(height: 8),
        ExitQuantityStepper(
          key: ValueKey('qty_${productId}_${variantId}_$batchKey'),
          value: quantity,
          max: maxAvailable,
          large: true,
          onChanged: onQuantityChanged,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Disponible: ${formatExitQty(maxAvailable)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 300) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: costField),
                  const SizedBox(width: 12),
                  Expanded(child: qtyField),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [costField, const SizedBox(height: 16), qtyField],
            );
          },
        ),
        const SizedBox(height: 20),
        _ExitLossBar(amount: quantity * unitCost),
      ],
    );
  }
}

class _ExitLossBar extends StatelessWidget {
  final double amount;
  const _ExitLossBar({required this.amount});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Pérdida estimada',
            style: textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(
              'S/ ${amount.toStringAsFixed(2)}',
              key: ValueKey(amount.toStringAsFixed(2)),
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.danger,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
