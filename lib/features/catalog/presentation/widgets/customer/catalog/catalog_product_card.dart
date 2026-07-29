import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class CatalogProductCard extends StatefulWidget {
  final ProductEntity product;
  final Future<void> Function(ProductEntity) onAddToCart;

  const CatalogProductCard({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  @override
  State<CatalogProductCard> createState() => _CatalogProductCardState();
}

class _CatalogProductCardState extends State<CatalogProductCard> {
  bool _isCardHovered = false;
  bool _isCardPressed = false;
  bool _isButtonHovered = false;
  bool _isAdding = false;

  Future<void> _handleAddToCart() async {
    if (_isAdding) return;

    setState(() => _isAdding = true);
    try {
      await widget.onAddToCart(widget.product);
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    bool isAgotado = false;
    if (product.stockControl) {
      isAgotado = product.totalStock <= 0;
    }

    final imageUrl =
        product.images.isNotEmpty
            ? product.images
                .firstWhere(
                  (img) => img.isMain,
                  orElse: () => product.images.first,
                )
                .imageUrl
            : null;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isCardHovered = true),
      onExit: (_) => setState(() => _isCardHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isCardPressed = true),
        onTapUp: (_) => setState(() => _isCardPressed = false),
        onTapCancel: () => setState(() => _isCardPressed = false),
        onTap: () {
          setState(() => _isCardPressed = false);
          context.go('/product/${product.id}', extra: product);
        },
        child: AnimatedScale(
          scale: _isCardPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color:
                    _isCardHovered
                        ? AppColors.primary.withValues(alpha: 0.3)
                        : Colors.grey.shade200,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      _isCardHovered
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.04),
                  blurRadius: _isCardHovered ? 16 : 10,
                  offset: Offset(0, _isCardHovered ? 6 : 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── CONTENEDOR DE IMAGEN ──
                Expanded(
                  flex: 6,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(17),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(17),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ColorFiltered(
                              colorFilter:
                                  isAgotado
                                      ? ColorFilter.mode(
                                        Colors.grey.shade400,
                                        BlendMode.saturation,
                                      )
                                      : const ColorFilter.mode(
                                        Colors.transparent,
                                        BlendMode.dst,
                                      ),
                              child:
                                  imageUrl != null
                                      ? CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        fit: BoxFit.contain,
                                        placeholder:
                                            (context, url) => Container(
                                              color: Colors.grey.shade100,
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: AppColors.primary,
                                                    ),
                                              ),
                                            ),
                                        errorWidget:
                                            (context, url, error) => Container(
                                              color: Colors.grey.shade100,
                                              child: Icon(
                                                Icons
                                                    .image_not_supported_outlined,
                                                color: Colors.grey.shade400,
                                                size: 36,
                                              ),
                                            ),
                                      )
                                      : Container(
                                        color: Colors.grey.shade100,
                                        child: Icon(
                                          Icons.inventory_2_outlined,
                                          color: Colors.grey.shade400,
                                          size: 36,
                                        ),
                                      ),
                            ),
                          ),
                        ),
                      ),
                      if (isAgotado)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.1),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(17),
                            ),
                          ),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'AGOTADO',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ── INFORMACIÓN DEL PRODUCTO ──
                Expanded(
                  flex: 4,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          product.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color:
                                isAgotado
                                    ? Colors.grey.shade500
                                    : AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                'S/ ${(product.displaySalePrice ?? 0).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.3,
                                  color:
                                      isAgotado
                                          ? Colors.grey.shade400
                                          : AppColors.primary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            MouseRegion(
                              onEnter:
                                  (_) =>
                                      setState(() => _isButtonHovered = true),
                              onExit:
                                  (_) =>
                                      setState(() => _isButtonHovered = false),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                height: 36,
                                width: 36,
                                decoration: BoxDecoration(
                                  color:
                                      isAgotado
                                          ? Colors.grey.shade300
                                          : (_isButtonHovered
                                              ? AppColors.primaryDark
                                              : AppColors.primary),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow:
                                      isAgotado || _isAdding
                                          ? []
                                          : [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 6,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(12),
                                    onTap:
                                        isAgotado || _isAdding
                                            ? null
                                            : _handleAddToCart,
                                    child: Center(
                                      child:
                                          _isAdding
                                              ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                              : Icon(
                                                Icons.add_shopping_cart_rounded,
                                                color:
                                                    isAgotado
                                                        ? Colors.white70
                                                        : Colors.white,
                                                size: 18,
                                              ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
