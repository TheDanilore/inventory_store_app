import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/providers/customer/customer_wishlist_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class WishlistCard extends StatelessWidget {
  final WishlistEntryModel entry;
  final bool isProcessing;
  final VoidCallback onAddToCart;
  final VoidCallback onRemove;

  const WishlistCard({
    super.key,
    required this.entry,
    required this.isProcessing,
    required this.onAddToCart,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final product = entry.product;
    final imageUrl = product.primaryImageUrl;
    final isActive = product.isActive;
    final inStock = product.totalStock > 0;
    final canBuy = isActive && inStock;

    String statusText;
    Color statusColor;
    Color statusBgColor;

    if (!isActive) {
      statusText = 'No disponible';
      statusColor = AppColors.textHint;
      statusBgColor = AppColors.background;
    } else if (inStock) {
      statusText = 'En stock';
      statusColor = AppColors.success;
      statusBgColor = AppColors.success.withValues(alpha: 0.10);
    } else {
      statusText = 'Agotado';
      statusColor = AppColors.error;
      statusBgColor = AppColors.error.withValues(alpha: 0.10);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap:
              () => context.push(
                '/customer/product/${product.id}',
                extra: product,
              ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagen
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child:
                          (imageUrl != null && imageUrl.isNotEmpty)
                              ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: 88,
                                height: 88,
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) => Container(
                                      width: 88,
                                      height: 88,
                                      color: AppColors.background,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: AppColors.textHint,
                                          ),
                                        ),
                                      ),
                                    ),
                                errorWidget:
                                    (context, url, error) => _imgFallback(),
                              )
                              : _imgFallback(),
                    ),
                    Positioned(
                      top: 6,
                      right: 6,
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color:
                              isActive
                                  ? AppColors.textPrimary
                                  : AppColors.textHint,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Text(
                            'S/ ${product.salePrice.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color:
                                  isActive
                                      ? AppColors.primary
                                      : AppColors.textHint,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusBgColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (entry.createdAt != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.bookmark_outline_rounded,
                              size: 11,
                              color: AppColors.textHint,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat(
                                'dd MMM yyyy',
                              ).format(entry.createdAt!.toLocal()),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 12),

                      // Acciones
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap:
                                  isProcessing
                                      ? null
                                      : (canBuy ? onAddToCart : null),
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color:
                                      canBuy
                                          ? AppColors.primary
                                          : AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.add_shopping_cart_rounded,
                                      size: 15,
                                      color:
                                          canBuy
                                              ? Colors.white
                                              : AppColors.textHint,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      !isActive
                                          ? 'No disponible'
                                          : (inStock
                                              ? 'Al carrito'
                                              : 'Sin stock'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            canBuy
                                                ? Colors.white
                                                : AppColors.textHint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Eliminar
                          GestureDetector(
                            onTap: isProcessing ? null : onRemove,
                            child: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child:
                                  isProcessing
                                      ? const Padding(
                                        padding: EdgeInsets.all(10.0),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.accent,
                                        ),
                                      )
                                      : const Icon(
                                        Icons.favorite_rounded,
                                        size: 18,
                                        color: AppColors.accent,
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
          ),
        ),
      ),
    );
  }

  Widget _imgFallback() => Container(
    width: 88,
    height: 88,
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Icon(
      Icons.inventory_2_outlined,
      size: 32,
      color: AppColors.textSecondary,
    ),
  );
}
