import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';

/// Barra horizontal compacta con chips deslizables para selección rápida de variantes.
class QuickViewVariantChipsBar extends StatelessWidget {
  final List<ProductVariantEntity> variants;
  final String activeVariantId;
  final int Function(String variantId) stockCalculator;
  final ValueChanged<String> onVariantSelected;

  const QuickViewVariantChipsBar({
    super.key,
    required this.variants,
    required this.activeVariantId,
    required this.stockCalculator,
    required this.onVariantSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (variants.length <= 1) return const SizedBox.shrink();

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.8)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        itemCount: variants.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, idx) {
          final v = variants[idx];
          final isSelected = v.id == activeVariantId;
          final vStock = stockCalculator(v.id);
          final vTitle =
              v.attributeValues.isNotEmpty
                  ? v.label
                  : (v.sku?.isNotEmpty == true ? v.sku! : 'Var. #${idx + 1}');

          return InkWell(
            onTap: () {
              AppFeedbackService.selectionClick();
              onVariantSelected(v.id);
            },
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow:
                    isSelected
                        ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                        : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? Colors.white.withValues(alpha: 0.2)
                              : (vStock <= 0
                                  ? AppColors.danger.withValues(alpha: 0.1)
                                  : AppColors.teal.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$vStock',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color:
                            isSelected
                                ? Colors.white
                                : (vStock <= 0
                                    ? AppColors.danger
                                    : AppColors.tealDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
