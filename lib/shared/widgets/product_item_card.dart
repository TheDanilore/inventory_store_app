import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_shimmer.dart';

/// Card de producto reutilizable para todos los detail sheets.
///
/// Unifica el código antes duplicado en:
/// - `po_detail_sheet.dart`
/// - `inventory_exit_detail_sheet.dart`
/// - `inventory_entry_detail_sheet.dart`
///
/// Soporta animación de entrada escalonada (staggered) por [animationDelay].
class ProductItemCard extends StatefulWidget {
  /// URL de la imagen del producto (nullable).
  final String? imageUrl;

  /// Nombre principal del producto.
  final String productName;

  /// Etiqueta de variante (ej. "Modelo: Spiderman"). `null` o `'Única'` → oculto.
  final String? variantLabel;

  /// Texto del badge inferior izquierdo (ej. "Recibido: 0 / 100", "SKU: ABC").
  final String? badgeText;

  /// Color del badge. Default: [AppColors.warning].
  final Color? badgeColor;

  /// Widget personalizado en la zona derecha (ej. precio, columna de precios).
  /// Si es `null`, no se renderiza nada a la derecha.
  final Widget? trailing;

  /// Widget extra debajo del nombre (ej. LinearProgressIndicator).
  final Widget? progressWidget;

  /// Delay para la animación de aparición escalonada.
  final Duration animationDelay;

  const ProductItemCard({
    super.key,
    this.imageUrl,
    required this.productName,
    this.variantLabel,
    this.badgeText,
    this.badgeColor,
    this.trailing,
    this.progressWidget,
    this.animationDelay = Duration.zero,
  });

  @override
  State<ProductItemCard> createState() => _ProductItemCardState();
}

class _ProductItemCardState extends State<ProductItemCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    Future.delayed(widget.animationDelay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = widget.badgeColor ?? AppColors.warning;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Imagen del producto ────────────────────────────────
              _ProductImage(imageUrl: widget.imageUrl),
              const SizedBox(width: 12),

              // ── Textos centrales ───────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (widget.variantLabel != null &&
                        widget.variantLabel!.isNotEmpty &&
                        widget.variantLabel != 'Única') ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.variantLabel!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    if (widget.progressWidget != null) ...[
                      const SizedBox(height: 6),
                      widget.progressWidget!,
                    ],

                    if (widget.badgeText != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        widget.badgeText!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: badgeColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Trailing (precio / columna de precios) ─────────────
              if (widget.trailing != null) ...[
                const SizedBox(width: 8),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget privado de imagen
// ─────────────────────────────────────────────────────────────────────────────

class _ProductImage extends StatelessWidget {
  final String? imageUrl;
  const _ProductImage({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child:
            imageUrl != null && imageUrl!.isNotEmpty
                ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  memCacheWidth: 104,
                  placeholder:
                      (_, _) => const AppShimmer(
                        width: 52,
                        height: 52,
                        borderRadius: 8,
                      ),
                  errorWidget: (_, _, _) => const _FallbackIcon(),
                )
                : const _FallbackIcon(),
      ),
    );
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon();

  @override
  Widget build(BuildContext context) => const Icon(
    Icons.image_not_supported_outlined,
    size: 22,
    color: AppColors.textHint,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers de trailing preformateados para cada tipo de sheet
// ─────────────────────────────────────────────────────────────────────────────

/// Precio simple alineado a la derecha.
class ItemPriceTrailing extends StatelessWidget {
  final String text;
  final Color? color;

  const ItemPriceTrailing({super.key, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 14,
        color: color ?? AppColors.textPrimary,
      ),
    );
  }
}

/// Columna de precios (cantidad + c/u + subtotal) para inventory_entry.
class ItemPriceColumnTrailing extends StatelessWidget {
  final String quantityText;
  final String unitCostText;
  final String subtotalText;

  const ItemPriceColumnTrailing({
    super.key,
    required this.quantityText,
    required this.unitCostText,
    required this.subtotalText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          quantityText,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          unitCostText,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
        Text(
          subtotalText,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }
}
