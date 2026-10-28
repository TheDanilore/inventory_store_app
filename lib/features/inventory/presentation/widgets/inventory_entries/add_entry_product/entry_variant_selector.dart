import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/add_entry_product/entry_product_formatters.dart';

class EntryVariantSelector extends StatelessWidget {
  final List<ProductVariantModel> variants;
  final ProductVariantModel? selectedVariant;
  final ValueChanged<ProductVariantModel?> onVariantChanged;

  const EntryVariantSelector({
    super.key,
    required this.variants,
    required this.selectedVariant,
    required this.onVariantChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    if (variants.length > 6) {
      return DropdownButtonFormField<ProductVariantModel>(
        initialValue: selectedVariant,
        isExpanded: true,
        icon: const Icon(Icons.expand_more_rounded),
        decoration: entryInputDecoration(hint: 'Selecciona una variante'),
        items:
            variants
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(
                      v.label,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
        onChanged: (val) {
          AppFeedbackService.lightImpact();
          onVariantChanged(val);
        },
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          variants.map((v) {
            final selected = selectedVariant?.id == v.id;
            return ChoiceChip(
              label: Text(v.label),
              selected: selected,
              showCheckmark: false,
              onSelected: (_) {
                AppFeedbackService.selectionClick();
                onVariantChanged(v);
              },
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.background,
              labelStyle: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
              side: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            );
          }).toList(),
    );
  }
}
