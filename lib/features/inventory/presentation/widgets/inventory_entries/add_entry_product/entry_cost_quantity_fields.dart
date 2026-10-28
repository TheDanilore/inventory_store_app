import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product/entry_product_common_widgets.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product/entry_product_formatters.dart';

class EntryCostQuantityFields extends StatelessWidget {
  final TextEditingController costCtrl;
  final TextEditingController qtyCtrl;
  final double currentCost;
  final double quantity;
  final VoidCallback onCostEdited;
  final ValueChanged<double> onQuantityChanged;

  const EntryCostQuantityFields({
    super.key,
    required this.costCtrl,
    required this.qtyCtrl,
    required this.currentCost,
    required this.quantity,
    required this.onCostEdited,
    required this.onQuantityChanged,
  });

  void _stepQuantity(int delta) {
    AppFeedbackService.selectionClick();
    final double base = quantity > 0 ? quantity : 0.0;
    double next = base + delta;
    if (next < 1) next = 1;
    qtyCtrl.text = fmtQty(next);
    qtyCtrl.selection = TextSelection.collapsed(offset: qtyCtrl.text.length);
    onQuantityChanged(next);
  }

  void _onQuantityTyped(String raw) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
    onQuantityChanged((parsed != null && parsed > 0) ? parsed : 0);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isZeroCost = currentCost == 0.0;

    final costField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EntryFieldLabel('Costo unitario'),
        const SizedBox(height: 8),
        TextField(
          controller: costCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          onTap:
              () =>
                  costCtrl.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: costCtrl.text.length,
                  ),
          onChanged: (_) => onCostEdited(),
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          decoration: entryInputDecoration(
            prefixText: 'S/ ',
            helper: isZeroCost ? 'Verifica el costo: está en S/ 0.00' : null,
            accent: isZeroCost ? AppColors.warning : null,
          ),
        ),
      ],
    );

    final qtyField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EntryFieldLabel('Cantidad'),
        const SizedBox(height: 8),
        _QuantityStepper(
          controller: qtyCtrl,
          canDecrease: quantity > 1,
          onDecrease: () => _stepQuantity(-1),
          onIncrease: () => _stepQuantity(1),
          onChanged: _onQuantityTyped,
        ),
      ],
    );

    return LayoutBuilder(
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
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final TextEditingController controller;
  final bool canDecrease;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final ValueChanged<String> onChanged;

  const _QuantityStepper({
    required this.controller,
    required this.canDecrease,
    required this.onDecrease,
    required this.onIncrease,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Semantics(
            label: 'Disminuir cantidad',
            button: true,
            child: _QtyButton(
              icon: Icons.remove_rounded,
              enabled: canDecrease,
              onTap: onDecrease,
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}')),
              ],
              onTap:
                  () =>
                      controller.selection = TextSelection(
                        baseOffset: 0,
                        extentOffset: controller.text.length,
                      ),
              onChanged: onChanged,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Semantics(
            label: 'Aumentar cantidad',
            button: true,
            child: _QtyButton(
              icon: Icons.add_rounded,
              enabled: true,
              onTap: onIncrease,
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _QtyButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10),
        splashColor: AppColors.primary.withValues(alpha: 0.18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 44,
          decoration: BoxDecoration(
            color:
                enabled
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: enabled ? AppColors.primary : AppColors.textMuted,
            size: 22,
          ),
        ),
      ),
    );
  }
}
