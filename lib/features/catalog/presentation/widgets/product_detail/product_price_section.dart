import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

// ─── PRICE SECTION ───────────────────────────────────────────────────────────

class ProductPriceSection extends StatelessWidget {
  final double effectivePrice;
  final double baseSalePrice;
  final double? baseWholesalePrice;
  final int baseWholesaleMinQty;
  final int selectedQty;

  const ProductPriceSection({
    super.key,
    required this.effectivePrice,
    required this.baseSalePrice,
    required this.baseWholesalePrice,
    required this.baseWholesaleMinQty,
    required this.selectedQty,
  });

  @override
  Widget build(BuildContext context) {
    final isWholesale =
        baseWholesalePrice != null && selectedQty >= baseWholesaleMinQty;
    final hasWholesale = baseWholesalePrice != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'S/',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
                height: 2.0,
              ),
            ),
            const SizedBox(width: 2),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.0, -0.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Text(
                effectivePrice.toStringAsFixed(2),
                key: ValueKey<double>(effectivePrice),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: -1.5,
                  height: 1.0,
                ),
              ),
            ),
            if (isWholesale) ...[
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'S/ ${baseSalePrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textMuted,
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const Spacer(),
            if (hasWholesale)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      isWholesale ? AppColors.amberLight : AppColors.background,
                  borderRadius: BorderRadius.circular(AppColors.radius),
                  border: Border.all(
                    color:
                        isWholesale
                            ? AppColors.amber.withValues(alpha: 0.5)
                            : AppColors.border,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.local_offer_rounded,
                      size: 14,
                      color:
                          isWholesale ? AppColors.amber : AppColors.textMuted,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'x$baseWholesaleMinQty+',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color:
                            isWholesale
                                ? AppColors.amberDark
                                : AppColors.textMuted,
                      ),
                    ),
                    Text(
                      'S/ ${baseWholesalePrice!.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 10,
                        color:
                            isWholesale ? AppColors.amber : AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        if (isWholesale) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.successLight,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '¡Ahorro mayorista de S/ ${(baseSalePrice - effectivePrice).toStringAsFixed(2)}!',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.success,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
        if (hasWholesale && !isWholesale) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.amberLight,
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  size: 14,
                  color: AppColors.amber,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Compra $baseWholesaleMinQty+ y paga S/ ${baseWholesalePrice!.toStringAsFixed(2)} c/u',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.amberDark,
                      fontWeight: FontWeight.w600,
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
