import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vibration/vibration.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class CatalogProductCard extends StatefulWidget {
  final ProductModel product;
  final Future<void> Function(ProductModel) onAddToCart;

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
  bool _isButtonHovered = false;
  bool _isAdding = false;

  Future<void> _handleAddToCart() async {
    if (_isAdding) return;

    if (!kIsWeb) Vibration.vibrate(duration: 50, amplitude: 128);

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
    final isAgotado = product.totalStock <= 0;

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
        onTap: () => context.go('/customer/product/${product.id}', extra: product),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isCardHovered ? Colors.grey.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(
                  alpha: _isCardHovered ? 0.12 : 0.07,
                ),
                blurRadius: _isCardHovered ? 20 : 14,
                offset: Offset(0, _isCardHovered ? 6 : 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── IMAGEN ──
              Expanded(
                flex: 5,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child:
                          imageUrl != null
                              ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder:
                                    (context, url) => Container(
                                      color: Colors.grey.shade200,
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                errorWidget:
                                    (context, url, error) => Container(
                                      color: Colors.grey.shade100,
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: Colors.grey.shade400,
                                        size: 40,
                                      ),
                                    ),
                              )
                              : Container(
                                color: Colors.grey.shade100,
                                child: Icon(
                                  Icons.inventory_2_outlined,
                                  color: Colors.grey.shade400,
                                  size: 40,
                                ),
                              ),
                    ),
                    if (isAgotado)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'AGOTADO',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // ── INFO ──
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color:
                                    isAgotado
                                        ? Colors.grey.shade500
                                        : Colors.grey.shade800,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'S/ ${product.salePrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color:
                                    isAgotado
                                        ? Colors.grey.shade400
                                        : AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: MouseRegion(
                          onEnter:
                              (_) => setState(() => _isButtonHovered = true),
                          onExit:
                              (_) => setState(() => _isButtonHovered = false),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            height: 38,
                            width: _isButtonHovered && !isAgotado ? 100 : 38,
                            decoration: BoxDecoration(
                              color:
                                  isAgotado
                                      ? Colors.grey.shade300
                                      : (_isAdding
                                          ? Colors.grey.shade400
                                          : AppColors.accent),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow:
                                  isAgotado || _isAdding
                                      ? []
                                      : [
                                        BoxShadow(
                                          color: AppColors.accent.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
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
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.add_shopping_cart_rounded,
                                                color:
                                                    isAgotado
                                                        ? Colors.white70
                                                        : Colors.white,
                                                size: 18,
                                              ),
                                              if (_isButtonHovered &&
                                                  !isAgotado) ...[
                                                const SizedBox(width: 6),
                                                const Flexible(
                                                  child: Text(
                                                    'Añadir',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.clip,
                                                    softWrap: false,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
