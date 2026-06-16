import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/models/product_variant_model.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart';

import 'package:inventory_store_app/services/customer/catalog_service.dart';

class CartVariantPickerSheet extends StatefulWidget {
  final CartProvider cart;
  final ProductModel product;

  const CartVariantPickerSheet({
    super.key,
    required this.cart,
    required this.product,
  });

  @override
  State<CartVariantPickerSheet> createState() => _CartVariantPickerSheetState();
}

class _CartVariantPickerSheetState extends State<CartVariantPickerSheet> {
  final _service = CatalogService();
  bool _isLoading = true;
  List<ProductVariantModel> _variants = [];
  Map<String, int> _stockByVariant = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final variantsData = await _service.loadActiveVariants(widget.product.id);
      _variants =
          variantsData.map((v) => ProductVariantModel.fromJson(v)).toList();
      _stockByVariant = await _service.loadStockByVariant(widget.product.id);
    } catch (e) {
      debugPrint('Error loading variants: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 200,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.teal),
          ),
        ),
      );
    }

    if (_variants.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const SafeArea(
          child: Text(
            'Este producto no tiene variantes disponibles o están inactivas.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

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
                'Selecciona una variación',
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
                      _variants.map((variant) {
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
    final int variantStock = _stockByVariant[variant.id] ?? 0;
    final bool isAgotado = widget.product.stockControl && variantStock <= 0;

    return InkWell(
      onTap:
          isAgotado
              ? null
              : () {
                if (!kIsWeb) Vibration.vibrate(duration: 50, amplitude: 128);
                widget.cart.addItem(
                  widget.product,
                  quantity: 1,
                  variantId: variant.id,
                  variantLabel: variant.label,
                  unitPrice: variant.salePrice ?? widget.product.salePrice,
                  wholesalePrice:
                      variant.wholesalePrice ?? widget.product.wholesalePrice,
                  unitCost: variant.unitCost ?? widget.product.unitCost,
                  imageUrl:
                      variant.primaryImageUrl ?? widget.product.primaryImageUrl,
                  sku: variant.sku,
                  availableStock: variantStock,
                );
                Navigator.pop(context);
                AppSnackbar.show(
                  context,
                  message:
                      '${widget.product.name} - ${variant.label} añadido al carrito',
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
                          : widget.product.images.isNotEmpty
                          ? CachedNetworkImage(
                            imageUrl: widget.product.images.first.imageUrl,
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
                    ] else if (widget.product.stockControl) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Stock: $variantStock',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Stock Libre',
                        style: TextStyle(
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
    color: AppColors.bg,
    child: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
  );
}
