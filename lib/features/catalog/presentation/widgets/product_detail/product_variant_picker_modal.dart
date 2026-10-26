import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';

/// Modal selector de variantes para ProductDetailScreen.
/// Extraído para modularizar y aligerar la vista principal.
class ProductVariantPickerModal extends StatelessWidget {
  final List<ProductVariantEntity> variants;
  final String? selectedVariantId;
  final String fallbackImageUrl;
  final String currencySymbol;
  final String? Function(ProductVariantEntity) variantImageUrl;
  final void Function(ProductVariantEntity) onVariantSelected;

  const ProductVariantPickerModal({
    super.key,
    required this.variants,
    required this.selectedVariantId,
    required this.fallbackImageUrl,
    required this.currencySymbol,
    required this.variantImageUrl,
    required this.onVariantSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required List<ProductVariantEntity> variants,
    required String? selectedVariantId,
    required String fallbackImageUrl,
    required String currencySymbol,
    required String? Function(ProductVariantEntity) variantImageUrl,
    required void Function(ProductVariantEntity) onVariantSelected,
  }) {
    if (variants.isEmpty) return Future.value();

    final isDesktop = MediaQuery.of(context).size.width >= 700;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final modalWidget = ProductVariantPickerModal(
      variants: variants,
      selectedVariantId: selectedVariantId,
      fallbackImageUrl: fallbackImageUrl,
      currencySymbol: currencySymbol,
      variantImageUrl: variantImageUrl,
      onVariantSelected: onVariantSelected,
    );

    if (isDesktop) {
      return showDialog<void>(
        context: context,
        builder:
            (dialogCtx) => Dialog(
              backgroundColor:
                  isDark ? AppColors.darkSurfaceElevated : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusLg),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 580,
                  maxHeight: 650,
                ),
                child: modalWidget,
              ),
            ),
      );
    }

    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (sheetCtx) => Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetCtx).size.height * 0.75,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: modalWidget,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Catálogo de Variantes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color:
                      isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: isDark ? const Color(0xFF94A3B8) : null,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          color: isDark ? AppColors.darkBorder : AppColors.divider,
        ),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(16),
            itemCount: variants.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (ctx, index) {
              final v = variants[index];
              final isSelected = v.id == selectedVariantId;
              final imgUrl = variantImageUrl(v) ?? fallbackImageUrl;

              return InkWell(
                onTap: () {
                  onVariantSelected(v);
                  Navigator.pop(ctx);
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? AppColors.primary.withValues(
                              alpha: isDark ? 0.2 : 0.06,
                            )
                            : (isDark
                                ? AppColors.darkSurfaceElevated
                                : AppColors.surface),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color:
                          isSelected
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.darkBorder
                                  : AppColors.border),
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child:
                            imgUrl.isNotEmpty
                                ? CachedNetworkImage(
                                  imageUrl: imgUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  fadeInDuration: const Duration(
                                    milliseconds: 100,
                                  ),
                                  placeholder:
                                      (context, url) => Container(
                                        width: 48,
                                        height: 48,
                                        color:
                                            isDark
                                                ? AppColors.darkSurface
                                                : Colors.grey.shade100,
                                      ),
                                  errorWidget:
                                      (context, url, error) => Container(
                                        width: 48,
                                        height: 48,
                                        color: Colors.grey.shade200,
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          size: 20,
                                          color: Colors.grey,
                                        ),
                                      ),
                                )
                                : Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              v.label,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                color:
                                    isDark
                                        ? const Color(0xFFF8FAFC)
                                        : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'SKU: ${v.sku ?? "N/A"}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$currencySymbol ${(v.salePrice ?? 0.0).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          if (v.wholesalePrice != null)
                            Text(
                              'Mayoreo: $currencySymbol ${v.wholesalePrice!.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 10),
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
