import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/pos/data/models/cart_item_model.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_variant_model.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_cubit.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter/foundation.dart';

import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';

class CartVariantPickerSheet extends StatefulWidget {
  final CartCubit cartCubit;
  final ProductEntity product;
  final CartItemEntity? existingCartItem;
  final int initialQuantity;
  final ValueChanged<ProductVariantEntity>? onVariantSelected;
  final String? selectedVariantId;

  const CartVariantPickerSheet({
    super.key,
    required this.cartCubit,
    required this.product,
    this.existingCartItem,
    this.initialQuantity = 1,
    this.onVariantSelected,
    this.selectedVariantId,
  });

  @override
  State<CartVariantPickerSheet> createState() => _CartVariantPickerSheetState();
}

class _CartVariantPickerSheetState extends State<CartVariantPickerSheet> {
  final _service = sl<ProductsRepository>();
  bool _isLoading = true;
  List<ProductVariantEntity> _variants = [];
  Map<String, int> _stockByVariant = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final variantsRes = await _service.loadActiveVariants(widget.product.id);
      final variantsData = variantsRes.fold(
        (l) => <Map<String, dynamic>>[],
        (r) => r,
      );
      _variants =
          variantsData
              .map((v) => ProductVariantModel.fromJson(v).toEntity())
              .toList();
      final stockRes = await _service.loadStockByVariant(widget.product.id);
      _stockByVariant = stockRes.fold((l) => <String, int>{}, (r) => r);
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
              child: GridView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.72,
                ),
                itemCount: _variants.length,
                itemBuilder: (context, index) {
                  return _buildVariantOption(context, _variants[index]);
                },
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
    ProductVariantEntity variant,
  ) {
    final int variantStock = _stockByVariant[variant.id] ?? 0;
    final bool isAgotado = widget.product.stockControl && variantStock <= 0;

    final bool isSelected = variant.id == widget.selectedVariantId;

    return InkWell(
      onTap:
          isAgotado
              ? null
              : () {
                if (!kIsWeb) Vibration.vibrate(duration: 50, amplitude: 128);

                final int quantity =
                    widget.existingCartItem?.quantity ?? widget.initialQuantity;

                if (widget.onVariantSelected != null) {
                  widget.onVariantSelected!(variant);
                  Navigator.pop(context);
                  return;
                }

                // Si estamos cambiando una variante desde el carrito
                if (widget.existingCartItem != null &&
                    widget.existingCartItem!.variantId != variant.id) {
                  widget.cartCubit.removeItem(widget.existingCartItem!.cartKey);
                }

                widget.cartCubit.addItem(
                  CartItemEntity(
                    productId: widget.product.id,
                    productName: widget.product.name,
                    cartKey: '${widget.product.id}_${variant.id}',
                    quantity: quantity,
                    variantId: variant.id,
                    variantLabel: variant.label,
                    unitPrice: variant.salePrice ?? widget.product.salePrice,
                    wholesalePrice: variant.wholesalePrice ?? widget.product.wholesalePrice,
                    wholesaleMinQuantity: widget.product.wholesaleMinQuantity,
                    unitCost: variant.unitCost ?? widget.product.unitCost,
                    imageUrl: (variant.images.isNotEmpty ? variant.images.first.imageUrl : null) ?? widget.product.primaryImageUrl,
                    sku: variant.sku,
                    availableStock: variantStock,
                    usesBatches: widget.product.stockControl,
                  ),
                );
                Navigator.pop(context);
                AppSnackbar.show(
                  context,
                  message:
                      widget.existingCartItem != null
                          ? 'Variante actualizada a ${variant.label}'
                          : '${widget.product.name} - ${variant.label} añadido al carrito',
                  backgroundColor: AppColors.success,
                );
              },
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: isAgotado ? 0.5 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color:
                isSelected ? AppColors.primary.withValues(alpha: 0.05) : null,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2.0 : 1.0,
            ),
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
                      variant.images.isNotEmpty
                          ? CachedNetworkImage(
                            imageUrl: variant.images.first.imageUrl,
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
    color: AppColors.background,
    child: const Icon(Icons.image_outlined, color: AppColors.textSecondary),
  );
}
