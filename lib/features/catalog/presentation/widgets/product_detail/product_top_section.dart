import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class ProductTopSection extends StatelessWidget {
  final String name;
  final String? sku;
  final bool isActive;
  final int effectiveStock;
  final double averageRating;
  final int totalReviews;

  const ProductTopSection({
    super.key,
    required this.name,
    required this.sku,
    required this.isActive,
    required this.effectiveStock,
    required this.averageRating,
    required this.totalReviews,
  });

  @override
  Widget build(BuildContext context) {
    final (statusLabel, statusColor, statusBg) =
        !isActive
            ? ('No disponible', AppColors.textSecondary, AppColors.slateLight)
            : effectiveStock > 0
            ? ('En stock', AppColors.success, AppColors.successLight)
            : ('Agotado', AppColors.danger, AppColors.dangerLight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: statusColor,
                ),
              ),
            ),
            if (sku != null && sku!.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                'SKU $sku',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          name,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.4,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 10),
        if (totalReviews > 0)
          Row(
            children: [
              ...List.generate(
                5,
                (i) => Icon(
                  i < averageRating.floor()
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: AppColors.amber,
                  size: 15,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '($totalReviews reseñas)',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
