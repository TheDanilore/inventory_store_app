import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class ProductReviewsCard extends StatelessWidget {
  final double averageRating;
  final int totalReviews;
  final List<Map<String, dynamic>> reviews;
  final VoidCallback onAddReview;

  const ProductReviewsCard({
    super.key,
    required this.averageRating,
    required this.totalReviews,
    required this.reviews,
    required this.onAddReview,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppColors.cardAdaptive(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CardHeader(
                icon: Icons.star_rounded,
                iconColor: const Color(0xFFF5A623),
                iconBg:
                    isDark
                        ? const Color(0xFF78350F).withValues(alpha: 0.4)
                        : const Color(0xFFFEF3C7),
                title: 'Reseñas',
              ),
              GestureDetector(
                onTap: onAddReview,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppColors.radius),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_rounded,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'Opinar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (totalReviews == 0) ...[
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.star_outline_rounded,
                    size: 36,
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sé el primero en opinar',
                    style: TextStyle(
                      fontSize: 13,
                      color:
                          isDark
                              ? const Color(0xFF94A3B8)
                              : AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            // Summary row
            Row(
              children: [
                Text(
                  averageRating.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color:
                        isDark
                            ? const Color(0xFFF8FAFC)
                            : AppColors.textPrimary,
                    letterSpacing: -1,
                    height: 1,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < averageRating.floor()
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: AppColors.amber,
                          size: 18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalReviews calificaciones',
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark
                                ? const Color(0xFF94A3B8)
                                : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(
              height: 1,
              color: isDark ? AppColors.darkBorder : AppColors.divider,
            ),
            const SizedBox(height: 14),
            ...reviews.take(3).map((r) => _ReviewRow(review: r)),
          ],
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final Map<String, dynamic> review;
  const _ReviewRow({required this.review});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = review['user_name']?.toString() ?? 'Usuario';
    final rating = (review['rating'] as num?)?.toInt() ?? 5;
    final comment = review['comment'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color:
                            isDark
                                ? const Color(0xFFF8FAFC)
                                : AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: List.generate(
                        5,
                        (i) => Icon(
                          i < rating
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: AppColors.amber,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              comment,
              style: TextStyle(
                fontSize: 13,
                color:
                    isDark
                        ? const Color(0xFF94A3B8)
                        : AppColors.textSecondary,
                height: 1.5,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.divider,
          ),
        ],
      ),
    );
  }
}
// ─── CARD HEADER ──────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  const _CardHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
