import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/product_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

/// Tarjeta de producto del catálogo admin con imagen, badges de estado y acciones.
class AdminProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onSale;
  final VoidCallback onToggleActive;
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
  Widget build(BuildContext context) {
    final isAgotado = product.stockControl && product.totalStock <= 0;
    final isDesactivado = !product.isActive;

    return GestureDetector(
      onTap: () => context.push('/product/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: isDesactivado ? const Color(0xFFF8FAFC) : Colors.white,
          borderRadius: BorderRadius.circular(AppColors.radius),
          border: Border.all(
            color:
                isDesactivado
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFFEDF2F7),
          ),
          boxShadow:
              isDesactivado
                  ? null
                  : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─ Imagen ─
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
                          product.images.isNotEmpty
                              ? CachedNetworkImage(
                                imageUrl:
                                    product.images
                                        .firstWhere(
                                          (img) => img.isMain,
                                          orElse: () => product.images.first,
                                        )
                                        .imageUrl,
                                fit: BoxFit.cover,
                                placeholder:
                                    (_, _) => const ColoredBox(
                                      color: Color(0xFFF1F5F9),
                                      child: Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.teal,
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

                  // Overlay INACTIVO
                  if (isDesactivado)
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppColors.radius),
                        ),
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.55),
                          child: const Center(
                            child: _StatusBadge(
                              label: 'INACTIVO',
                              color: Color(0xFFEF4444),
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
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.45),
                          child: const Center(
                            child: _StatusBadge(
                              label: 'AGOTADO',
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Badge de stock
                  if (!isDesactivado && !isAgotado && product.stockControl)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${product.totalStock}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ─ Info ─
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
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
                  if (highlightIngredient != null &&
                      highlightIngredient!.isNotEmpty) ...[
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
                            size: 9,
                            color: Color(0xFF059669),
                          ),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              highlightIngredient!,
                              style: const TextStyle(
                                fontSize: 9,
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
                    'S/ ${product.salePrice.toStringAsFixed(2)}',
                    style: TextStyle(
                      color:
                          isDesactivado ? AppColors.textMuted : AppColors.teal,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // ─ Acciones ─
            Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              padding: const EdgeInsets.symmetric(vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _CardAction(
                    icon: Icons.point_of_sale_rounded,
                    enabled: !isAgotado && !isDesactivado,
                    activeColor: AppColors.teal,
                    tooltip: 'Vender',
                    onTap: (!isAgotado && !isDesactivado) ? onSale : null,
                  ),
                  _CardAction(
                    icon: Icons.edit_rounded,
                    enabled: true,
                    activeColor: AppColors.blue,
                    tooltip: 'Editar',
                    onTap: onEdit,
                  ),
                  _CardAction(
                    icon:
                        isDesactivado
                            ? Icons.check_circle_outline_rounded
                            : Icons.visibility_off_rounded,
                    enabled: true,
                    activeColor:
                        isDesactivado
                            ? AppColors.success
                            : AppColors.textSecondary,
                    tooltip: isDesactivado ? 'Activar' : 'Desactivar',
                    onTap: onToggleActive,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets privados ──────────────────────────────────────────────────────────

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

class _CardAction extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color activeColor;
  final String tooltip;
  final VoidCallback? onTap;

  const _CardAction({
    required this.icon,
    required this.enabled,
    required this.activeColor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 36,
              child: Icon(
                icon,
                size: 18,
                color: enabled ? activeColor : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
