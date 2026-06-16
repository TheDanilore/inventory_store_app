import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart';

class CartVariantPickerSheet extends StatelessWidget {
  final CartProvider cart;
  final ProductModel product;

  const CartVariantPickerSheet({
    super.key,
    required this.cart,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Selecciona una variacin',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      product.productVariants.map((variant) {
                        return _buildVariantOption(context, variant);
                      }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildVariantOption(
    BuildContext context,
    ProductVariantModel variant,
  ) {
    final double stockDouble = product.warehouseStockBatches
        .where((b) => b.variantId == variant.id)
        .fold(0.0, (sum, b) => sum + b.availableQuantity);
    final int variantStock = stockDouble.toInt();
    final bool isAgotado = variantStock <= 0;

    return InkWell(
      onTap:
          isAgotado
              ? null
              : () {
                if (!kIsWeb) Vibration.vibrate(duration: 50, amplitude: 128);
                cart.addItem(
                  product,
                  quantity: 1,
                  variantId: variant.id,
                  variantLabel: variant.label,
                  unitPrice: variant.salePrice ?? product.salePrice,
                  wholesalePrice:
                      variant.wholesalePrice ?? product.wholesalePrice,
                  unitCost: variant.unitCost ?? product.unitCost,
                  imageUrl: variant.primaryImageUrl ?? product.primaryImageUrl,
                  sku: variant.sku,
                  availableStock: variantStock,
                );
                Navigator.pop(context);
                AppSnackbar.show(
                  context,
                  message:
                      '${product.name} - ${variant.label} aadido al carrito',
                  backgroundColor: AppColors.success,
                );
              },
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: isAgotado ? 0.5 : 1.0,
        child: Container(
          width: 140,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: AspectRatio(
                  aspectRatio: 1,
                  child:
                      variant.primaryImageUrl != null
                          ? CachedNetworkImage(
                            imageUrl: variant.primaryImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => _imgFallback(),
                            errorWidget:
                                (context, url, error) => _imgFallback(),
                          )
                          : product.images.isNotEmpty
                          ? CachedNetworkImage(
                            imageUrl: product.images.first.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => _imgFallback(),
                            errorWidget:
                                (context, url, error) => _imgFallback(),
                          )
                          : _imgFallback(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      variant.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (isAgotado) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Agotado',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        'Stock: $variantStock',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imgFallback() => Container(
    color: AppColors.background,
    child: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
  );
}
