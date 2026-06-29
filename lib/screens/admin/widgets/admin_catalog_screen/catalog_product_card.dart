import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

/// Tarjeta de producto del catálogo admin con imagen, badges de estado y acciones.
class AdminProductCard extends StatefulWidget {
  final ProductModel product;
  final VoidCallback onSale;
  final Future<void> Function() onToggleActive;
  final VoidCallback onEdit;
  final String? highlightIngredient;

  const AdminProductCard({
    super.key,
    required this.product,
    required this.onSale,
    required this.onToggleActive,
    required this.onEdit,
    this.highlightIngredient,
  });

  @override
  State<AdminProductCard> createState() => _AdminProductCardState();
}

class _AdminProductCardState extends State<AdminProductCard> {
  bool _isToggling = false;
  bool _isCardPressed = false;
  bool _isHovered = false;

  /// Devuelve el color del badge de stock según nivel de alerta.
  Color _stockBadgeColor(int stock) {
    if (stock <= 5) return const Color(0xFFEF4444); // 🔴 crítico
    if (stock <= 15) return const Color(0xFFF59E0B); // 🟡 bajo
    return Colors.black.withValues(alpha: 0.60); // ⚫ normal
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

  @override
  Widget build(BuildContext context) {
    final isAgotado =
        widget.product.stockControl && widget.product.totalStock <= 0;
    final isDesactivado = !widget.product.isActive;

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
          onTap:
              () => context.go(
                '/admin/product/${widget.product.id}',
                extra: widget.product,
              ),
          onLongPress: () {
            HapticFeedback.mediumImpact();
            // Podría abrir un modal o bottomSheet de acciones secundarias
          },
          child: Ink(
            decoration: BoxDecoration(
              color: isDesactivado ? const Color(0xFFF8FAFC) : Colors.white,
              borderRadius: BorderRadius.circular(AppColors.radius),
              border: Border.all(
                color:
                    isDesactivado
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFFE5E7EB),
                width: 1.0,
              ),
              boxShadow:
                  isDesactivado
                      ? null
                      : [
                        if (_isHovered)
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          )
                        else
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
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
                        child: Opacity(
                          opacity: isDesactivado ? 0.45 : 1.0,
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
                                    placeholder:
                                        (_, _) => ColoredBox(
                                          color: const Color(0xFFF1F5F9),
                                          child: Center(
                                            child: SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color:
                                                    Theme.of(
                                                      context,
                                                    ).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                    errorWidget:
                                        (_, _, _) => const ColoredBox(
                                          color: Color(0xFFF1F5F9),
                                          child: Icon(
                                            Icons.image_not_supported_rounded,
                                            size: 40,
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                  )
                                  : const ColoredBox(
                                    color: Color(0xFFF1F5F9),
                                    child: Icon(
                                      Icons.image_not_supported_rounded,
                                      size: 40,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                        ),
                      ),

                      // Overlay de carga al hacer toggle
                      if (_isToggling)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppColors.radius),
                            ),
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.40),
                              child: const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      // Overlay INACTIVO
                      else if (isDesactivado)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppColors.radius),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                              child: ColoredBox(
                                color: Colors.white.withValues(alpha: 0.3),
                                child: const Center(
                                  child: _StatusBadge(
                                    label: 'INACTIVO',
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      // Overlay AGOTADO
                      else if (isAgotado)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(AppColors.radius),
                            ),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                              child: ColoredBox(
                                color: Colors.white.withValues(alpha: 0.3),
                                child: const Center(
                                  child: _StatusBadge(
                                    label: 'AGOTADO',
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
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
                                  fontSize:
                                      11, // Aumentado de 10 a 11 para legibilidad
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
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize:
                              13, // ↑ subido de 12 a 13 para mejor jerarquía
                          color:
                              isDesactivado
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                          decoration:
                              isDesactivado ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (widget.highlightIngredient != null &&
                          widget.highlightIngredient!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: const Color(0xFF6EE7B7)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.science_rounded,
                                size: 11, // Aumentado de 9 a 11
                                color: Color(0xFF059669),
                              ),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(
                                  widget.highlightIngredient!,
                                  style: const TextStyle(
                                    fontSize: 11, // Aumentado de 9 a 11
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF065F46),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 3),
                      Text(
                        'S/ ${widget.product.salePrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          // ↑ color más oscuro: #0B7A73 da ratio ~4.6:1 sobre blanco (cumple WCAG AA)
                          color:
                              isDesactivado
                                  ? AppColors.textMuted
                                  : const Color(0xFF0B7A73),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

                // ─ Acciones ───────────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      // Botón primario: "Vender" con label visible
                      _PrimaryCardAction(
                        icon: Icons.point_of_sale_rounded,
                        label: 'Vender',
                        enabled: !isAgotado && !isDesactivado,
                        color: Theme.of(context).colorScheme.primary,
                        onTap:
                            (!isAgotado && !isDesactivado)
                                ? () {
                                  HapticFeedback.lightImpact();
                                  widget.onSale();
                                }
                                : null,
                      ),
                      // Divisor visual
                      Container(width: 1, height: 18, color: AppColors.border),
                      // Botón Editar
                      _IconCardAction(
                        icon: Icons.edit_rounded,
                        tooltip: 'Editar producto',
                        color: Colors.blue,
                        onTap: widget.onEdit,
                      ),
                      // Botón Activar / Desactivar
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
                                : AppColors.textSecondary,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
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

/// Botón de acción primario: pill con ícono + label (para "Vender").
class _PrimaryCardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final Color color;
  final VoidCallback? onTap;

  const _PrimaryCardAction({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(10),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 40,
                decoration: BoxDecoration(
                  color:
                      enabled
                          ? color.withValues(alpha: 0.10)
                          : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: enabled ? color : AppColors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: enabled ? color : AppColors.textMuted,
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
                height: 40,
                child: Icon(
                  icon,
                  size: 18,
                  color: isDisabled ? AppColors.textMuted : color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
