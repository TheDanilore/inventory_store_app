import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

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
  final bool isDialog;

  const CartVariantPickerSheet({
    super.key,
    required this.cartCubit,
    required this.product,
    this.existingCartItem,
    this.initialQuantity = 1,
    this.onVariantSelected,
    this.selectedVariantId,
    this.isDialog = false,
  });

  static Future<void> show({
    required BuildContext context,
    required CartCubit cartCubit,
    required ProductEntity product,
    CartItemEntity? existingCartItem,
    int initialQuantity = 1,
    ValueChanged<ProductVariantEntity>? onVariantSelected,
    String? selectedVariantId,
  }) async {
    final isDesktop = MediaQuery.of(context).size.width >= 700;

    if (isDesktop) {
      await showDialog<void>(
        context: context,
        builder:
            (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 540,
                  maxHeight: 620,
                ),
                child: CartVariantPickerSheet(
                  cartCubit: cartCubit,
                  product: product,
                  existingCartItem: existingCartItem,
                  initialQuantity: initialQuantity,
                  onVariantSelected: onVariantSelected,
                  selectedVariantId: selectedVariantId,
                  isDialog: true,
                ),
              ),
            ),
      );
    } else {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (context) => CartVariantPickerSheet(
              cartCubit: cartCubit,
              product: product,
              existingCartItem: existingCartItem,
              initialQuantity: initialQuantity,
              onVariantSelected: onVariantSelected,
              selectedVariantId: selectedVariantId,
            ),
      );
    }
  }

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
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              widget.isDialog
                  ? BorderRadius.circular(20)
                  : const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      );
    }

    if (_variants.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              widget.isDialog
                  ? BorderRadius.circular(20)
                  : const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isDialog)
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
              const Text(
                'Este producto no tiene variantes disponibles o están inactivas.',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            widget.isDialog
                ? BorderRadius.circular(20)
                : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.isDialog) ...[
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
            ] else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Selecciona una variación',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.product.name,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: AppColors.textSecondary,
                      ),
                      tooltip: 'Cerrar',
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
            const SizedBox(height: 12),
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
                  childAspectRatio: 0.75,
                ),
                itemCount: _variants.length,
                itemBuilder: (context, index) {
                  return _buildVariantOption(context, _variants[index]);
                },
              ),
            ),
            const SizedBox(height: 20),
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
    final price = variant.salePrice ?? widget.product.displaySalePrice ?? 0.0;

    return InkWell(
      onTap: () {
        if (!kIsWeb) Vibration.vibrate(duration: 30, amplitude: 80);

        final int quantity =
            widget.existingCartItem?.quantity ?? widget.initialQuantity;

        if (widget.onVariantSelected != null) {
          widget.onVariantSelected!(variant);
          Navigator.pop(context);
          return;
        }

        if (isAgotado) {
          AppSnackbar.show(
            context,
            message: '${variant.label} está agotado, no se puede añadir.',
            type: SnackbarType.error,
          );
          return;
        }

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
            unitPrice: price,
            wholesalePrice: variant.wholesalePrice,
            wholesaleMinQuantity: variant.wholesaleMinQuantity ?? 3,
            unitCost: variant.unitCost ?? 0,
            imageUrl:
                (variant.images.isNotEmpty
                    ? variant.images.first.imageUrl
                    : null) ??
                widget.product.primaryImageUrl,
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
          type: SnackbarType.success,
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: isAgotado ? 0.55 : 1.0,
        child: Container(
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.primary.withValues(alpha: 0.05)
                    : Colors.white,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 2.0 : 1.0,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: isSelected ? 0.1 : 0.03,
                ),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(15),
                      ),
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
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          variant.label,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'S/ ${price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (isAgotado)
                          const Text(
                            'Agotado',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        else if (widget.product.stockControl)
                          Text(
                            'Stock: $variantStock',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          )
                        else
                          const Text(
                            'Disponible',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isSelected)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imgFallback() => Container(
    color: Colors.grey.shade100,
    child: const Center(
      child: Icon(
        Icons.image_outlined,
        color: AppColors.textSecondary,
        size: 28,
      ),
    ),
  );
}
