import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_state.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PosCartItemsSection extends StatelessWidget {
  final Function(CartItemEntity item) onShowBatchEditSheet;

  const PosCartItemsSection({super.key, required this.onShowBatchEditSheet});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, CartState>(
      builder: (context, state) {
        if (state.items.isEmpty) {
          return Container(
            height: 120,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.border,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: 32,
                  color: AppColors.textMuted,
                ),
                SizedBox(height: 8),
                Text(
                  'La caja está vacía',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.radius),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow(),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.items.length,
            separatorBuilder:
                (_, _) => const Divider(height: 1, color: AppColors.border),
            itemBuilder: (context, index) {
              final item = state.items.values.elementAt(index);
              return PosCartItemRow(
                item: item,
                onShowBatchEditSheet: () => onShowBatchEditSheet(item),
              );
            },
          ),
        );
      },
    );
  }
}

class PosCartItemRow extends StatelessWidget {
  final CartItemEntity item;
  final VoidCallback onShowBatchEditSheet;

  const PosCartItemRow({
    super.key,
    required this.item,
    required this.onShowBatchEditSheet,
  });

  Future<void> _showQuantityDialog(BuildContext context) async {
    final qtyCtrl = TextEditingController(text: item.quantity.toString());

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text(
              'Modificar cantidad',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            content: TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
                helperText: 'Stock disponible: ${item.availableStock}',
                helperStyle: const TextStyle(
                  color: AppColors.tealDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tealDark,
                ),
                onPressed: () {
                  final newQty = int.tryParse(qtyCtrl.text.trim());
                  if (newQty != null && newQty >= 0) {
                    context.read<CartCubit>().updateQuantity(
                      item.cartKey,
                      newQty,
                    );
                    Navigator.pop(dialogContext);
                  }
                },
                child: const Text(
                  'Guardar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Inject PosCubit to check for batch overrides.
    final bool hasBatchOverride = context
        .watch<PosCubit>()
        .state
        .batchOverrides
        .containsKey(item.cartKey);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child:
                  item.imageUrl != null
                      ? CachedNetworkImage(
                        imageUrl: item.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder:
                            (context, url) => const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        errorWidget:
                            (context, url, error) => const Icon(
                              Icons.image_not_supported,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                      )
                      : const Icon(
                        Icons.inventory_2_outlined,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (item.variantLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.variantLabel!,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (item.usesBatches) ...[
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: onShowBatchEditSheet,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tealLight,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: AppColors.teal.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasBatchOverride
                                ? Icons.edit_note_rounded
                                : Icons.auto_mode_rounded,
                            size: 10,
                            color:
                                hasBatchOverride
                                    ? AppColors.warningDark
                                    : AppColors.tealDark,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasBatchOverride ? 'Lotes manuales' : 'FEFO Auto',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color:
                                  hasBatchOverride
                                      ? AppColors.warningDark
                                      : AppColors.tealDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap:
                                item.quantity > 1
                                    ? () => context
                                        .read<CartCubit>()
                                        .updateQuantity(
                                          item.cartKey,
                                          item.quantity - 1,
                                        )
                                    : null,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(6),
                            ),
                            child: Container(
                              width: 28,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.remove_rounded,
                                size: 14,
                                color:
                                    item.quantity > 1
                                        ? AppColors.textSecondary
                                        : AppColors.textMuted,
                              ),
                            ),
                          ),
                          Material(
                            color: AppColors.tealLight.withValues(alpha: 0.3),
                            child: InkWell(
                              onTap: () => _showQuantityDialog(context),
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 28),
                                alignment: Alignment.center,
                                child: Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.tealDark,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap:
                                item.quantity < item.availableStock
                                    ? () => context
                                        .read<CartCubit>()
                                        .updateQuantity(
                                          item.cartKey,
                                          item.quantity + 1,
                                        )
                                    : null,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(6),
                            ),
                            child: Container(
                              width: 28,
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.add_rounded,
                                size: 14,
                                color:
                                    item.quantity < item.availableStock
                                        ? AppColors.textSecondary
                                        : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'S/ ${item.unitPrice.toStringAsFixed(2)} c/u',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'S/ ${item.subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => context.read<CartCubit>().removeItem(item.cartKey),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Icon(
                    Icons.delete_rounded,
                    size: 14,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class PosWholesaleHint extends StatelessWidget {
  final TextEditingController quantityController;
  final ProductVariantModel? selectedVariant;
  final ProductEntity product;
  final bool useWholesalePrice;
  final bool canUseWholesalePrice;

  const PosWholesaleHint({
    super.key,
    required this.quantityController,
    required this.selectedVariant,
    required this.product,
    required this.useWholesalePrice,
    required this.canUseWholesalePrice,
  });

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) {
        final quantity = int.tryParse(quantityController.text) ?? 0;
        final wholesalePrice =
            selectedVariant?.wholesalePrice ?? product.wholesalePrice;
        final minQty =
            selectedVariant?.wholesaleMinQuantity ??
            product.wholesaleMinQuantity;
        final hasWholesalePrice = wholesalePrice != null;

        final isPositive = useWholesalePrice && (quantity >= (minQty));
        final label =
            !hasWholesalePrice
                ? 'No hay precio por mayor configurado en esta variante ni en el producto'
                : !canUseWholesalePrice
                ? 'Necesitas $minQty unidades para aplicar precio por mayor'
                : useWholesalePrice
                ? (quantity >= (minQty)
                    ? 'Precio por mayor habilitado (Mín: $minQty)'
                    : 'Necesitas $minQty unidades para precio por mayor')
                : 'Precio base activo. Activa el switch para precio por mayor';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isPositive ? AppColors.successLight : Colors.blue.shade300,
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Row(
            children: [
              Icon(
                isPositive
                    ? Icons.check_circle_outline_rounded
                    : Icons.info_outline_rounded,
                size: 14,
                color: isPositive ? AppColors.success : Colors.blue,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isPositive ? AppColors.success : Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
