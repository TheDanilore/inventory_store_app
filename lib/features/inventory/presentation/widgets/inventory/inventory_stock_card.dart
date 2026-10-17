import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory/inventory_palette.dart';

class InventoryStockCard extends StatelessWidget {
  final InventoryStockItem item;
  final bool isSelected;
  final VoidCallback? onTap;

  const InventoryStockCard({
    super.key,
    required this.item,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color stockColor;
    if (item.stock <= 0) {
      stockColor = AppColors.danger;
    } else if (item.isLowStock) {
      stockColor = AppColors.warning;
    } else {
      stockColor = AppColors.success;
    }

    final double stockRatio =
        item.stockControl && item.reorderPoint > 0
            ? (item.stock / (item.reorderPoint * 4)).clamp(0.0, 1.0)
            : 1.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: InventoryPalette.of(context).surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isSelected
                  ? AppColors.primary
                  : InventoryPalette.of(context).border,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: AppColors.cardShadow(),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap:
              onTap ??
              () {
                context.go(
                  '/product/${item.productId}?variantId=${item.variantId}',
                );
              },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Thumbnail de Producto Premium ──
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: InventoryPalette.of(context).background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: InventoryPalette.of(context).border,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child:
                            item.imageUrl != null && item.imageUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                  imageUrl: item.imageUrl!,
                                  memCacheWidth: 140,
                                  memCacheHeight: 140,
                                  fit: BoxFit.cover,
                                  placeholder:
                                      (context, url) => Container(
                                        color:
                                            InventoryPalette.of(
                                              context,
                                            ).background,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                  errorWidget:
                                      (context, url, error) => Icon(
                                        Icons.broken_image_outlined,
                                        size: 20,
                                        color:
                                            InventoryPalette.of(
                                              context,
                                            ).textMuted,
                                      ),
                                )
                                : Icon(
                                  Icons.inventory_2_outlined,
                                  size: 22,
                                  color: InventoryPalette.of(context).textMuted,
                                ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // ── Información Principal del Stock ──
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.productName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color:
                                        InventoryPalette.of(
                                          context,
                                        ).textPrimary,
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Píldora de Stock con alto contraste WCAG
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: stockColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: stockColor.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${item.stock}',
                                      style: TextStyle(
                                        color: stockColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      'uds.',
                                      style: TextStyle(
                                        color: stockColor,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            [
                              item.category,
                              if (item.attrsText.trim().isNotEmpty &&
                                  item.attrsText.trim() != 'Única' &&
                                  item.attrsText.trim().toLowerCase() !=
                                      'variante estándar' &&
                                  item.attrsText.trim().toLowerCase() !=
                                      'variante única')
                                item.attrsText,
                              if (item.sku != null &&
                                  item.sku!.trim().isNotEmpty &&
                                  item.sku!.trim() != 'N/A')
                                'SKU: ${item.sku}',
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 12,
                              color: InventoryPalette.of(context).textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),

                          // ── Precios, Márgenes y Alertas ──
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _PriceTag(
                                label:
                                    'S/ ${item.salePrice.toStringAsFixed(2)}',
                                color: AppColors.primary,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: (item.margin >= 30
                                          ? AppColors.success
                                          : item.margin >= 15
                                          ? AppColors.warning
                                          : AppColors.danger)
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Margen: ${item.margin.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                    color:
                                        item.margin >= 30
                                            ? AppColors.success
                                            : item.margin >= 15
                                            ? AppColors.warning
                                            : AppColors.danger,
                                  ),
                                ),
                              ),
                              if (item.isLowStock)
                                const _Badge(
                                  label: 'Bajo stock',
                                  color: AppColors.warning,
                                  icon: Icons.warning_amber_rounded,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Indicador de Nivel de Stock (Progress Bar) ──
              if (item.stockControl)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stockRatio,
                      backgroundColor: stockColor.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(stockColor),
                      minHeight: 4,
                    ),
                  ),
                ),

              if (item.usesBatches && item.batches.isNotEmpty)
                _BatchSummary(batches: item.batches),

              // ── Pie de Tarjeta (una sola fila) ──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.flag_outlined,
                      size: 13,
                      color: InventoryPalette.of(context).textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'Reorden: ${item.reorderPoint} uds.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: InventoryPalette.of(context).textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    _FooterChip(
                      icon: Icons.receipt_long_rounded,
                      label: 'Kárdex',
                      foreground: InventoryPalette.of(context).textSecondary,
                      background: InventoryPalette.of(context).subtle,
                      onTap: () {
                        context.push(
                          '/kardex?productId=${item.productId}&variantId=${item.variantId}&productName=${Uri.encodeComponent(item.productName)}&variantName=${Uri.encodeComponent(item.attrsText)}',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resumen de lotes en UNA línea: cantidad de lotes + vencimiento más próximo.
class _BatchSummary extends StatelessWidget {
  final List<InventoryBatchItem> batches;
  const _BatchSummary({required this.batches});

  @override
  Widget build(BuildContext context) {
    final active = batches.where((b) => b.availableQuantity > 0).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    // Vencimiento más próximo entre los lotes con stock
    DateTime? nearest;
    for (final b in active) {
      final d = b.expiryDate != null ? DateTime.tryParse(b.expiryDate!) : null;
      if (d != null && (nearest == null || d.isBefore(nearest))) nearest = d;
    }

    Color color = InventoryPalette.of(context).textSecondary;
    String label = 'Sin vencimiento';
    if (nearest != null) {
      final diff = nearest.difference(DateTime.now()).inDays;
      if (diff < 0) {
        color = AppColors.danger;
        label = 'Vencido';
      } else if (diff <= 30) {
        color = AppColors.warning;
        label = 'Vence en $diff días';
      } else {
        color = AppColors.success;
        label =
            '${nearest.day.toString().padLeft(2, '0')}/${nearest.month.toString().padLeft(2, '0')}/${nearest.year}';
      }
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: InventoryPalette.of(context).background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: InventoryPalette.of(context).border),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '${active.length} lote${active.length != 1 ? 's' : ''}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: InventoryPalette.of(context).textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            nearest != null && active.length > 1 ? 'Próx. $label' : label,
            style: TextStyle(
              fontSize: 11.5,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final VoidCallback? onTap;

  const _FooterChip({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  final String label;
  final Color color;

  const _PriceTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w800,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
