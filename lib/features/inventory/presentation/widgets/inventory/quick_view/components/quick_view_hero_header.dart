import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Encabezado Hero de la Ficha Rápida con imagen/monograma, títulos, badges y chips interactivos de SKU y código de barras.
class QuickViewHeroHeader extends StatelessWidget {
  final String productName;
  final String? activeVariantTitle;
  final String? imageUrl;
  final String? sku;
  final String? barcode;
  final String category;
  final String? activeIngredient;
  final int currentStock;
  final bool isLowStock;

  const QuickViewHeroHeader({
    super.key,
    required this.productName,
    this.activeVariantTitle,
    this.imageUrl,
    this.sku,
    this.barcode,
    required this.category,
    this.activeIngredient,
    required this.currentStock,
    required this.isLowStock,
  });

  Widget _buildMonogram(String name, double size) {
    final clean = name.trim();
    String initials = 'PR';
    if (clean.isNotEmpty) {
      final parts = clean.split(RegExp(r'\s+'));
      if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        initials = '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      } else {
        initials =
            clean.length >= 2
                ? clean.substring(0, 2).toUpperCase()
                : clean[0].toUpperCase();
      }
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSemanticAvailabilityBadge(int stock, bool isLowStock) {
    final isOut = stock <= 0;

    Color bgColor;
    Color textColor;
    Color borderColor;
    IconData iconData;
    String text;

    if (isOut) {
      bgColor = AppColors.danger.withValues(alpha: 0.08);
      borderColor = AppColors.danger.withValues(alpha: 0.25);
      textColor = AppColors.danger;
      iconData = Icons.highlight_off_rounded;
      text = 'Agotado (0 uds.)';
    } else if (isLowStock) {
      bgColor = AppColors.warning.withValues(alpha: 0.1);
      borderColor = AppColors.warning.withValues(alpha: 0.3);
      textColor = AppColors.warningDark;
      iconData = Icons.warning_amber_rounded;
      text = 'Bajo Stock ($stock uds.)';
    } else {
      bgColor = AppColors.teal.withValues(alpha: 0.1);
      borderColor = AppColors.teal.withValues(alpha: 0.25);
      textColor = AppColors.tealDark;
      iconData = Icons.check_circle_outline_rounded;
      text = 'En Stock ($stock uds.)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 12.5, color: textColor),
          const SizedBox(width: 4.5),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveTitle =
        activeVariantTitle != null &&
        activeVariantTitle!.isNotEmpty &&
        activeVariantTitle != productName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen o Monograma
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child:
                  imageUrl != null && imageUrl!.isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: imageUrl!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        placeholder:
                            (ctx, url) => Container(
                              width: 72,
                              height: 72,
                              color: AppColors.background,
                            ),
                        errorWidget:
                            (ctx, url, err) => _buildMonogram(productName, 72),
                      )
                      : _buildMonogram(productName, 72),
            ),
            const SizedBox(width: 14),

            // Título, Variante y Chips
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  if (hasActiveTitle) ...[
                    const SizedBox(height: 3),
                    Text(
                      activeVariantTitle!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildSemanticAvailabilityBadge(currentStock, isLowStock),
                      if (sku != null && sku!.isNotEmpty)
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: sku!));
                            AppFeedbackService.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('SKU copiado al portapapeles'),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.copy_rounded,
                                  size: 11,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  sku!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace',
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (barcode != null && barcode!.isNotEmpty)
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: barcode!));
                            AppFeedbackService.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Código de barras copiado al portapapeles',
                                ),
                                duration: Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.teal.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: AppColors.teal.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.barcode_reader,
                                  size: 12,
                                  color: AppColors.tealDark,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  barcode!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'monospace',
                                    color: AppColors.tealDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (category.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            category,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        if (activeIngredient != null && activeIngredient!.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.accentLight.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.accent.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.science_outlined,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Principio Activo: $activeIngredient',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
