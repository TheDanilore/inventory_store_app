import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/cart_item_model.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';
import 'package:inventory_store_app/providers/customer/cart_checkout_provider.dart';
import 'package:inventory_store_app/screens/customer/widgets/cart/cart_variant_picker_sheet.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:provider/provider.dart';

class CartItemCard extends StatelessWidget {
  final String productId;
  final CartItemModel item;
  final CartProvider cart;
  final int saldoPuntos;
  final double pointsToSolesRatio;

  const CartItemCard({
    super.key,
    required this.productId,
    required this.item,
    required this.cart,
    required this.saldoPuntos,
    required this.pointsToSolesRatio,
  });

  @override
  Widget build(BuildContext context) {
    final checkoutProvider = context.read<CartCheckoutProvider>();
    final product = item.product;
    final wPrice = checkoutProvider.wholesalePriceOf(item);

    final String? imageUrl =
        item.imageUrl ??
        (product.images.isNotEmpty
            ? product.images
                .firstWhere(
                  (img) => img.isMain,
                  orElse: () => product.images.first,
                )
                .imageUrl
            : null);

    final isWholesale = item.quantity >= (product.wholesaleMinQuantity);
    final appliedPoints = checkoutProvider.getAppliedPointsForItem(
      item,
      cart,
      pointsToSolesRatio,
      saldoPuntos,
    );
    final hasPointDiscount = appliedPoints > 0;

    final displayUnitPrice = isWholesale ? wPrice : item.unitPrice;
    final totalPrice = displayUnitPrice * item.quantity;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Checkbox
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: item.isSelected,
              activeColor: AppColors.textPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              side: BorderSide(color: Colors.grey.shade400, width: 1.5),
              onChanged: (val) {
                cart.toggleItemSelection(productId);
              },
            ),
          ),
          const SizedBox(width: 12),
          // Imagen
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child:
                imageUrl != null
                    ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => _buildImagePlaceholder(),
                      errorWidget:
                          (context, url, error) => _buildImagePlaceholder(),
                    )
                    : _buildImagePlaceholder(),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                if (item.variantLabel != null) ...[
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder:
                            (context) => CartVariantPickerSheet(
                              cart: cart,
                              product: product,
                              existingCartItem: item,
                            ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              item.variantLabel!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                // Precios
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'S/ ${displayUnitPrice.toStringAsFixed(2)} c/u',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (hasPointDiscount)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.stars_rounded,
                                  size: 10,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '-$appliedPoints pts',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    Text(
                      'S/ ${totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Stepper Vertical
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _stepperButton(
                icon: Icons.add_rounded,
                bgColor: const Color(0xFF1E1E2D),
                iconColor: Colors.white,
                onTap: () {
                  if (item.quantity >= item.availableStock) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Has alcanzado el stock máximo'),
                      ),
                    );
                    return;
                  }
                  cart.setQuantity(productId, item.quantity + 1);
                },
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              _stepperButton(
                icon: Icons.remove_rounded,
                bgColor: const Color(0xFFFFF0F2),
                iconColor: const Color(0xFFE53935),
                onTap: () {
                  if (item.quantity > 1) {
                    cart.setQuantity(productId, item.quantity - 1);
                  } else {
                    cart.removeItem(productId);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: 70,
      height: 70,
      color: Colors.grey.shade100,
      child: Icon(Icons.image_outlined, size: 24, color: Colors.grey.shade400),
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
  }
}
