import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/services/product_ocr_scanner_service.dart';
import 'package:inventory_store_app/features/pos/presentation/services/variant_disambiguation_helper.dart';

/// Modal flotante para seleccionar una presentación o variante cuando el OCR detecta ambigüedad.
class OcrVariantsSheet extends StatelessWidget {
  final ProductOcrMatchResult result;
  final ValueChanged<ProductVariantEntity> onVariantSelected;
  final VoidCallback onClose;

  const OcrVariantsSheet({
    super.key,
    required this.result,
    required this.onVariantSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.7),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFF59E0B),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.product.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        result.detectedPresentation != null
                            ? 'Detectado: "${result.detectedPresentation}". Elige presentación:'
                            : 'Selecciona la presentación detectada:',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white60,
                    size: 18,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  result.candidateVariants.map((variant) {
                    final label =
                        variant.shortLabel.isNotEmpty
                            ? variant.shortLabel
                            : variant.label;
                    final price =
                        variant.salePrice != null
                            ? 'S/ ${variant.salePrice!.toStringAsFixed(2)}'
                            : '';
                    final isSuggested =
                        result.detectedPresentation != null &&
                        VariantDisambiguationHelper.normalize(label).contains(
                          VariantDisambiguationHelper.normalize(
                            result.detectedPresentation!,
                          ),
                        );

                    return InkWell(
                      onTap: () => onVariantSelected(variant),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSuggested
                                  ? const Color(
                                    0xFFF59E0B,
                                  ).withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isSuggested
                                    ? const Color(0xFFF59E0B)
                                    : Colors.white24,
                            width: isSuggested ? 1.5 : 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSuggested) ...[
                              const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFF59E0B),
                                size: 15,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              label,
                              style: TextStyle(
                                color:
                                    isSuggested
                                        ? const Color(0xFFFDE68A)
                                        : Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (price.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Text(
                                price,
                                style: const TextStyle(
                                  color: AppColors.teal,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
