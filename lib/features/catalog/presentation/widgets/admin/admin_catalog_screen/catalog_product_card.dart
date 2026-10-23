import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/utils/brand_logo_helper.dart';
import 'package:inventory_store_app/features/catalog/presentation/widgets/product_image_placeholder.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

/// Tarjeta de producto del catálogo admin con imagen, badges de estado y acciones.
class AdminProductCard extends StatefulWidget {
  final ProductEntity product;
  final VoidCallback onSale;
  final Future<void> Function() onToggleActive;
  final VoidCallback onEdit;
  final VoidCallback? onTap;
  final String? highlightIngredient;
  final bool isFullPosMode;
  final bool isSelected;

  const AdminProductCard({
    super.key,
    required this.product,
    required this.onSale,
    required this.onToggleActive,
    required this.onEdit,
    this.onTap,
    this.highlightIngredient,
    this.isFullPosMode = false,
    this.isSelected = false,
  });

  @override
  State<AdminProductCard> createState() => _AdminProductCardState();
}

class _AdminProductCardState extends State<AdminProductCard> {
  bool _isToggling = false;
  bool _isCardPressed = false;
  bool _isHovered = false;

  /// Matriz de escala de grises de alto rendimiento (evita shaders no separables como BlendMode.saturation
  /// que provocan sangrado de texturas y fallos de composición sobre vistas de plataforma HTML en Flutter Web).
  static const ColorFilter _grayscaleMatrix = ColorFilter.matrix(<double>[
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0.2126,
    0.7152,
    0.0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ]);

  /// Devuelve el color del badge de stock según nivel de alerta.
  Color _stockBadgeColor(int stock) {
    if (stock <= 5) return const Color(0xFFEF4444); //  crítico
    if (stock <= 15) return const Color(0xFFF59E0B); //  bajo
    return Colors.black.withValues(alpha: 0.60); //  normal
  }

  /// Maneja el toggle con estado de carga local.
  Future<void> _handleToggle() async {
    if (_isToggling) return;
    setState(() => _isToggling = true);
    try {
      await widget.onToggleActive();
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  /// Placeholder temático por categoría cuando no hay imagen de producto.
  Widget _buildProductPlaceholder(String name, bool isDark) {
    return ProductImagePlaceholder(
      productName: name,
      categoryName: widget.product.categoryName,
      isDark: isDark,
      borderRadius: 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAgotado =
        widget.product.stockControl && widget.product.totalStock <= 0;
    final isDesactivado = !widget.product.isActive;
    final activeIng =
        (widget.highlightIngredient != null &&
                widget.highlightIngredient!.isNotEmpty)
            ? widget.highlightIngredient!
            : null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppColors.radius),
      child: AnimatedScale(
        scale: _isCardPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppColors.radius),
          splashColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.04),
          onHighlightChanged:
              (isPressed) => setState(() => _isCardPressed = isPressed),
          onHover: (hover) => setState(() => _isHovered = hover),
          onTap: () {
            if (widget.onTap != null) {
              widget.onTap!();
            } else if (widget.isFullPosMode) {
              if (!isAgotado && !isDesactivado) {
                HapticFeedback.lightImpact();
                widget.onSale();
              }
            } else {
              context.go(
                '/product/${widget.product.id}',
                extra: widget.product,
              );
            }
          },
          onLongPress: () {
            HapticFeedback.mediumImpact();
          },
          child: Ink(
            decoration: BoxDecoration(
              color:
                  isDesactivado
                      ? (isDark
                          ? AppColors.darkSurface.withValues(alpha: 0.5)
                          : const Color(0xFFF8FAFC))
                      : (isDark ? AppColors.darkSurface : Colors.white),
              borderRadius: BorderRadius.circular(AppColors.radius),
              border: Border.all(
                color:
                    widget.isSelected
                        ? AppColors.primary
                        : (isDesactivado
                            ? (isDark
                                ? AppColors.darkBorder.withValues(alpha: 0.5)
                                : const Color(0xFFE2E8F0))
                            : (isDark
                                ? AppColors.darkBorder
                                : const Color(0xFFE5E7EB))),
                width: widget.isSelected ? 2.0 : 1.0,
              ),
              boxShadow:
                  isDesactivado
                      ? null
                      : [
                        if (_isHovered)
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.25 : 0.08,
                            ),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          )
                        else
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.15 : 0.02,
                            ),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                      ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ─ Imagen ─────────────────────────────────────────────────────
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppColors.radius),
                        ),
                        child: Builder(
                          builder: (context) {
                            final imageWidget = Opacity(
                              opacity:
                                  isDesactivado
                                      ? 0.45
                                      : (isAgotado ? 0.75 : 1.0),
                              child:
                                  widget.product.images.isNotEmpty
                                      ? CachedNetworkImage(
                                        imageUrl:
                                            widget.product.images
                                                .firstWhere(
                                                  (img) => img.isMain,
                                                  orElse:
                                                      () =>
                                                          widget
                                                              .product
                                                              .images
                                                              .first,
                                                )
                                                .imageUrl,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 350,
                                        memCacheHeight: 350,
                                        maxWidthDiskCache: 600,
                                        maxHeightDiskCache: 600,
                                        placeholder:
                                            (_, _) => ColoredBox(
                                              color:
                                                  isDark
                                                      ? AppColors
                                                          .darkSurfaceElevated
                                                      : const Color(0xFFF1F5F9),
                                              child: Center(
                                                child: SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .primary,
                                                      ),
                                                ),
                                              ),
                                            ),
                                        errorWidget:
                                            (_, _, _) =>
                                                _buildProductPlaceholder(
                                                  widget.product.name,
                                                  isDark,
                                                ),
                                      )
                                      : _buildProductPlaceholder(
                                        widget.product.name,
                                        isDark,
                                      ),
                            );

                            if (isAgotado) {
                              return ColorFiltered(
                                colorFilter: _grayscaleMatrix,
                                child: imageWidget,
                              );
                            }
                            return imageWidget;
                          },
                        ),
                      ),

                      // Overlay de carga al hacer toggle
                      if (_isToggling)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.40),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppColors.radius),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        )
                      // Overlay INACTIVO (sin blur que cause jank o distorsión)
                      else if (isDesactivado)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? Colors.black.withValues(alpha: 0.50)
                                      : Colors.white.withValues(alpha: 0.45),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppColors.radius),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const _StatusBadge(
                              label: 'INACTIVO',
                              color: Color(0xFFEF4444),
                            ),
                          ),
                        )
                      // Overlay AGOTADO (imagen nítida reconocible + badge de alto contraste)
                      else if (isAgotado)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.35 : 0.12,
                              ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(AppColors.radius),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const _StatusBadge(
                              label: 'AGOTADO',
                              color: Color(0xFF334155),
                            ),
                          ),
                        ),

                      // Badge de stock con color-coding por nivel
                      if (!isDesactivado &&
                          !isAgotado &&
                          widget.product.stockControl)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Semantics(
                            label:
                                '${widget.product.totalStock} unidades en stock',
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _stockBadgeColor(
                                  widget.product.totalStock,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.15),
                                    blurRadius: 4,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Text(
                                '${widget.product.totalStock}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // ─ Info ───────────────────────────────────────────────────────
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    10,
                    widget.isFullPosMode ? 6 : 8,
                    10,
                    widget.isFullPosMode ? 8 : 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.product.brandName != null &&
                          widget.product.brandName!.trim().isNotEmpty) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            BrandLogoHelper.buildBrandLogo(
                              name: widget.product.brandName!,
                              logoUrl: widget.product.brandLogoUrl,
                              size: 13,
                              borderRadius: 3,
                              showBorder: false,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                widget.product.brandName!.trim().toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.textMuted,
                                  letterSpacing: 0.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                      ],
                      Text(
                        widget.product.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: widget.isFullPosMode ? 12.5 : 13,
                          color:
                              isDesactivado
                                  ? (isDark
                                      ? AppColors.darkTextMuted
                                      : AppColors.textMuted)
                                  : (isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.textPrimary),
                          decoration:
                              isDesactivado ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (activeIng != null && activeIng.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isDark
                                    ? const Color(
                                      0xFF064E3B,
                                    ).withValues(alpha: 0.35)
                                    : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color:
                                  isDark
                                      ? const Color(
                                        0xFF059669,
                                      ).withValues(alpha: 0.5)
                                      : const Color(0xFF6EE7B7),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.science_rounded,
                                size: 11,
                                color:
                                    isDark
                                        ? const Color(0xFF34D399)
                                        : const Color(0xFF059669),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  activeIng,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isDark
                                            ? const Color(0xFF6EE7B7)
                                            : const Color(0xFF065F46),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'S/ ${(widget.product.displaySalePrice ?? 0).toStringAsFixed(2)}',
                            style: TextStyle(
                              color:
                                  isDesactivado
                                      ? (isDark
                                          ? AppColors.darkTextMuted
                                          : AppColors.textMuted)
                                      : (isDark
                                          ? const Color(0xFF34D399)
                                          : AppColors.tealDark),
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          if (widget.isFullPosMode)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color:
                                    isAgotado
                                        ? (isDark
                                            ? AppColors.darkSurfaceHighlight
                                            : Colors.grey.shade100)
                                        : (isDark
                                            ? AppColors.tealDark.withValues(
                                              alpha: 0.3,
                                            )
                                            : AppColors.tealLight.withValues(
                                              alpha: 0.6,
                                            )),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isAgotado
                                    ? Icons.block_rounded
                                    : (widget.product.productVariants.length > 1
                                        ? Icons.tune_rounded
                                        : Icons.add_rounded),
                                size: 15,
                                color:
                                    isAgotado
                                        ? (isDark
                                            ? AppColors.darkTextMuted
                                            : AppColors.textMuted)
                                        : (isDark
                                            ? const Color(0xFF34D399)
                                            : AppColors.tealDark),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ─ Acciones (Solo para catálogo admin tradicional, en POS la tarjeta entera es la acción) ─
                if (!widget.isFullPosMode)
                  Container(
                    margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    decoration: BoxDecoration(
                      color:
                          isDark
                              ? AppColors.darkSurfaceElevated
                              : AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _PrimaryCardAction(
                          icon: Icons.edit_rounded,
                          label: 'Editar',
                          enabled: true,
                          color:
                              isDark
                                  ? const Color(0xFF60A5FA)
                                  : const Color(0xFF2563EB),
                          onTap: widget.onEdit,
                          isFullWidth: false,
                        ),
                        Container(
                          width: 1,
                          height: 18,
                          color:
                              isDark ? AppColors.darkBorder : AppColors.border,
                        ),
                        _IconCardAction(
                          icon:
                              _isToggling
                                  ? Icons.hourglass_top_rounded
                                  : (isDesactivado
                                      ? Icons.check_circle_outline_rounded
                                      : Icons.visibility_off_rounded),
                          tooltip:
                              isDesactivado
                                  ? 'Activar producto'
                                  : 'Desactivar producto',
                          color:
                              isDesactivado
                                  ? AppColors.success
                                  : (isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textSecondary),
                          onTap: _isToggling ? null : _handleToggle,
                        ),
                      ],
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

// ─── Widgets privados ─────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.40),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _PrimaryCardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final Color color;
  final VoidCallback? onTap;
  final bool isFullWidth;

  const _PrimaryCardAction({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.color,
    required this.onTap,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius =
        isFullWidth
            ? BorderRadius.circular(10)
            : const BorderRadius.only(bottomLeft: Radius.circular(10));

    return Expanded(
      flex: 3,
      child: Semantics(
        label: label,
        button: true,
        child: Tooltip(
          message: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              mouseCursor:
                  enabled
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.forbidden,
              borderRadius: radius,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44,
                decoration: BoxDecoration(
                  color:
                      enabled
                          ? color.withValues(alpha: isDark ? 0.18 : 0.10)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03)),
                  borderRadius: radius,
                  border:
                      !enabled && isFullWidth
                          ? Border.all(
                            color:
                                isDark
                                    ? AppColors.darkBorder
                                    : AppColors.border,
                            width: 0.5,
                          )
                          : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color:
                          enabled
                              ? color
                              : (isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.textMuted),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color:
                            enabled
                                ? color
                                : (isDark
                                    ? AppColors.darkTextMuted
                                    : AppColors.textMuted),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón de acción secundario: solo ícono (para Editar y Toggle).
class _IconCardAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final dynamic onTap; // VoidCallback? o Future<void> Function()?

  const _IconCardAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDisabled = onTap == null;
    return Expanded(
      flex: 2,
      child: Semantics(
        label: tooltip,
        button: true,
        child: Tooltip(
          message: tooltip,
          preferBelow: false,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isDisabled ? null : () => onTap(),
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 44,
                child: Icon(
                  icon,
                  size: 18,
                  color:
                      isDisabled
                          ? (isDark
                              ? AppColors.darkTextMuted
                              : AppColors.textMuted)
                          : color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
