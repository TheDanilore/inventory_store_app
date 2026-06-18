import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ─── VARIANT SELECTOR ────────────────────────────────────────────────────────

class ProductVariantSelector extends StatelessWidget {
  final List<String> attributeKeys;
  final Map<String, List<String>> attributeOptions;
  final Map<String, String> selectedAttributes;
  final String Function(String) formatLabel;
  final bool Function(String, String) isOptionEnabled;
  final void Function(String, String) onSelect;
  final Map<String, String?> variantImageUrls;
  final String? fallbackImageUrl;

  const ProductVariantSelector({
    super.key,
    required this.attributeKeys,
    required this.attributeOptions,
    required this.selectedAttributes,
    required this.formatLabel,
    required this.isOptionEnabled,
    required this.onSelect,
    this.variantImageUrls = const {},
    this.fallbackImageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          attributeKeys.map((key) {
            final options = attributeOptions[key] ?? [];
            final selected = selectedAttributes[key];
            final hasImages = options.any(
              (opt) => variantImageUrls[opt] != null,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _formatLabel(key),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (selected != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            selected,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children:
                        options.map((option) {
                          final isSelected = selected == option;
                          final enabled = isOptionEnabled(key, option);
                          final imgUrl =
                              variantImageUrls[option] ?? fallbackImageUrl;

                          return GestureDetector(
                            onTap: enabled ? () => onSelect(key, option) : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: EdgeInsets.only(
                                left: (hasImages && imgUrl != null) ? 6 : 16,
                                right: 16,
                                top: (hasImages && imgUrl != null) ? 6 : 10,
                                bottom: (hasImages && imgUrl != null) ? 6 : 10,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    isSelected
                                        ? AppColors.primary.withValues(
                                          alpha: 0.1,
                                        )
                                        : enabled
                                        ? AppColors.bg
                                        : AppColors.surface,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? AppColors.primary
                                          : enabled
                                          ? AppColors.border
                                          : AppColors.divider,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasImages && imgUrl != null) ...[
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: AppColors.border,
                                      backgroundImage:
                                          CachedNetworkImageProvider(imgUrl),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Text(
                                    option,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight:
                                          isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                      color:
                                          isSelected
                                              ? AppColors.primary
                                              : enabled
                                              ? AppColors.textPrimary
                                              : AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  String _formatLabel(String value) {
    final n = value.replaceAll('_', ' ').trim();
    if (n.isEmpty) return value;
    return n
        .split(RegExp(r'\s+'))
        .map(
          (p) =>
              p.isEmpty ? p : p[0].toUpperCase() + p.substring(1).toLowerCase(),
        )
        .join(' ');
  }
}
