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
                  if (hasImages)
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: options.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, idx) {
                          final option = options[idx];
                          final isSelected = selected == option;
                          final enabled = isOptionEnabled(key, option);
                          final imgUrl =
                              variantImageUrls[option] ?? fallbackImageUrl;
                          return GestureDetector(
                            onTap: enabled ? () => onSelect(key, option) : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 72,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  AppColors.radius,
                                ),
                                border: Border.all(
                                  color:
                                      isSelected
                                          ? AppColors.primary
                                          : enabled
                                          ? AppColors.border
                                          : AppColors.divider,
                                  width: isSelected ? 2.5 : 1.5,
                                ),
                                boxShadow:
                                    isSelected
                                        ? [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.18,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 3),
                                          ),
                                        ]
                                        : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppColors.radius - 1,
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child:
                                          imgUrl != null
                                              ? CachedNetworkImage(
                                                imageUrl: imgUrl,
                                                fit: BoxFit.cover,
                                                color:
                                                    enabled
                                                        ? null
                                                        : Colors.white
                                                            .withValues(
                                                              alpha: 0.6,
                                                            ),
                                                colorBlendMode:
                                                    BlendMode.srcATop,
                                                placeholder:
                                                    (context, url) => Container(
                                                      color: AppColors.bg,
                                                      child: const Center(
                                                        child: SizedBox(
                                                          width: 12,
                                                          height: 12,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                errorWidget:
                                                    (_, _, _) => Container(
                                                      color: AppColors.bg,
                                                      child: const Icon(
                                                        Icons
                                                            .inventory_2_outlined,
                                                        size: 22,
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                    ),
                                              )
                                              : Container(
                                                color: AppColors.bg,
                                                child: const Icon(
                                                  Icons.inventory_2_outlined,
                                                  size: 22,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              (isSelected
                                                      ? AppColors.primary
                                                      : Colors.black)
                                                  .withValues(alpha: 0.72),
                                            ],
                                          ),
                                        ),
                                        child: Text(
                                          option,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color:
                                                enabled
                                                    ? Colors.white
                                                    : Colors.white.withValues(
                                                      alpha: 0.45,
                                                    ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        top: 5,
                                        right: 5,
                                        child: Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 11,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          options.map((option) {
                            final isSelected = selected == option;
                            final enabled = isOptionEnabled(key, option);
                            return GestureDetector(
                              onTap:
                                  enabled ? () => onSelect(key, option) : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? AppColors.primary
                                          : enabled
                                          ? Colors.white
                                          : AppColors.bg,
                                  borderRadius: BorderRadius.circular(
                                    AppColors.radius,
                                  ),
                                  border: Border.all(
                                    color:
                                        isSelected
                                            ? AppColors.primary
                                            : enabled
                                            ? AppColors.border
                                            : AppColors.divider,
                                    width: isSelected ? 2 : 1.5,
                                  ),
                                  boxShadow:
                                      isSelected
                                          ? [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.2),
                                              blurRadius: 10,
                                              offset: const Offset(0, 3),
                                            ),
                                          ]
                                          : null,
                                ),
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight:
                                        isSelected
                                            ? FontWeight.w800
                                            : FontWeight.w600,
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : enabled
                                            ? AppColors.textPrimary
                                            : AppColors.textMuted,
                                  ),
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
