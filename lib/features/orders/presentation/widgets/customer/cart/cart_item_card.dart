import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/checkout_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/customer/cart/cart_variant_picker_sheet.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class CartItemCard extends StatelessWidget {
  final String productId;
  final CartItemEntity item;
  final CartCubit cartCubit;
  final int saldoPuntos;
  final double pointsToSolesRatio;

  const CartItemCard({
    super.key,
    required this.productId,
    required this.item,
    required this.cartCubit,
    required this.saldoPuntos,
    required this.pointsToSolesRatio,
  });

  void _showDirectQuantityDialog(BuildContext context) {
    final controller = TextEditingController(text: '${item.quantity}');
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.edit_note_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Editar Cantidad',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.productName,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Cantidad deseada',
                  labelStyle: const TextStyle(color: AppColors.primary),
                  suffixText: 'unidades',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _buildQuickAddChip(context, controller, 5),
                  _buildQuickAddChip(context, controller, 10),
                  _buildQuickAddChip(context, controller, 50),
                  _buildQuickAddChip(context, controller, 100),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final newQty = int.tryParse(controller.text) ?? item.quantity;
                if (newQty <= 0) {
                  cartCubit.removeItem(item.cartKey);
                } else {
                  if (item.usesBatches &&
                      item.availableStock > 0 &&
                      newQty > item.availableStock) {
                    AppSnackbar.show(
                      context,
                      message:
                          'Cantidad ajustada al stock máximo disponible (${item.availableStock})',
                      type: SnackbarType.warning,
                    );
                    cartCubit.updateQuantity(item.cartKey, item.availableStock);
                  } else {
                    cartCubit.updateQuantity(item.cartKey, newQty);
                  }
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Guardar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickAddChip(
    BuildContext context,
    TextEditingController controller,
    int value,
  ) {
    return ActionChip(
      label: Text('+$value'),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: AppColors.primary,
      ),
      backgroundColor: AppColors.primary.withValues(alpha: 0.08),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onPressed: () {
        final current = int.tryParse(controller.text) ?? 0;
        controller.text = '${current + value}';
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final checkoutCubit = context.read<CheckoutCubit>();
    final wPrice = checkoutCubit.wholesalePriceOf(item);
    final String? imageUrl = item.imageUrl;

    final isWholesale =
        item.wholesaleMinQuantity > 0 &&
        item.quantity >= item.wholesaleMinQuantity;

    final config = context.read<AppConfigCubit>();
    final isLoyaltyEnabled =
        config.loyaltyGlobalEnabled && config.loyaltyCustomerVisible;

    final appliedPoints =
        isLoyaltyEnabled
            ? checkoutCubit.getAppliedPointsForItem(
              item,
              cartCubit,
              pointsToSolesRatio,
              saldoPuntos,
            )
            : 0;
    final hasPointDiscount = appliedPoints > 0;

    final displayUnitPrice = isWholesale ? wPrice : item.unitPrice;
    final totalPrice = displayUnitPrice * item.quantity;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Checkbox
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: item.isSelected,
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                  onChanged: (val) {
                    cartCubit.toggleItemSelection(item.cartKey, val ?? false);
                  },
                ),
              ),
              const SizedBox(width: 10),
              // Imagen del producto
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child:
                      imageUrl != null
                          ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.contain,
                            placeholder:
                                (context, url) => _buildImagePlaceholder(),
                            errorWidget:
                                (context, url, error) =>
                                    _buildImagePlaceholder(),
                          )
                          : _buildImagePlaceholder(),
                ),
              ),
              const SizedBox(width: 12),
              // Info del producto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (item.variantLabel != null) ...[
                      GestureDetector(
                        onTap: () async {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder:
                                (_) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                          );

                          final repo = sl<ProductsRepository>();
                          final res = await repo.getProductById(item.productId);

                          if (context.mounted) {
                            Navigator.pop(context); // cerrar loader
                          }

                          res.fold((l) => null, (product) {
                            if (product != null && context.mounted) {
                              CartVariantPickerSheet.show(
                                context: context,
                                cartCubit: cartCubit,
                                product: product,
                                existingCartItem: item,
                                selectedVariantId: item.variantId,
                              );
                            }
                          });
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    item.variantLabel!,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
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
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          // Fila Inferior: Precio Total & Stepper Horizontal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Subtotal:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
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
              // Stepper Horizontal con entrada directa
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StepperButton(
                      icon: Icons.remove_rounded,
                      bgColor: Colors.white,
                      iconColor:
                          item.quantity > 1
                              ? AppColors.textPrimary
                              : Colors.red.shade600,
                      onTap: () {
                        if (item.quantity > 1) {
                          cartCubit.updateQuantity(
                            item.cartKey,
                            item.quantity - 1,
                          );
                        } else {
                          cartCubit.removeItem(item.cartKey);
                        }
                      },
                    ),
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () => _showDirectQuantityDialog(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _StepperButton(
                      icon: Icons.add_rounded,
                      bgColor: AppColors.primary,
                      iconColor: Colors.white,
                      onTap: () {
                        if (item.usesBatches &&
                            item.availableStock > 0 &&
                            item.quantity >= item.availableStock) {
                          AppSnackbar.show(
                            context,
                            message:
                                'Has alcanzado el stock máximo disponible (${item.availableStock})',
                            type: SnackbarType.warning,
                          );
                          return;
                        }
                        cartCubit.updateQuantity(
                          item.cartKey,
                          item.quantity + 1,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 24,
          color: Colors.grey.shade400,
        ),
      ),
    );
  }
}

class _StepperButton extends StatefulWidget {
  final IconData icon;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _StepperButton({
    required this.icon,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_StepperButton> createState() => _StepperButtonState();
}

class _StepperButtonState extends State<_StepperButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: widget.bgColor,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(widget.icon, size: 18, color: widget.iconColor),
          ),
        ),
      ),
    );
  }
}
