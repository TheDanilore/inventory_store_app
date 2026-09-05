import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

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
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
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
                  '/admin/product/${item.productId}?variantId=${item.variantId}',
                );
              },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Thumbnail de Producto Premium ──
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child:
                            item.imageUrl != null && item.imageUrl!.isNotEmpty
                                ? CachedNetworkImage(
                                  imageUrl: item.imageUrl!,
                                  fit: BoxFit.cover,
                                  placeholder:
                                      (context, url) => Container(
                                        color: AppColors.background,
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
                                      (context, url, error) => const Icon(
                                        Icons.broken_image_outlined,
                                        size: 20,
                                        color: AppColors.textMuted,
                                      ),
                                )
                                : const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 22,
                                  color: AppColors.textMuted,
                                ),
                      ),
                    ),
                    const SizedBox(width: 14),

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
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
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
                              if (item.attrsText.isNotEmpty &&
                                  item.attrsText != 'Única')
                                item.attrsText,
                              if (item.sku != null && item.sku!.isNotEmpty)
                                'SKU: ${item.sku}',
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: stockRatio,
                      backgroundColor: stockColor.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation(stockColor),
                      minHeight: 6,
                    ),
                  ),
                ),

              if (item.usesBatches && item.batches.isNotEmpty)
                _BatchMiniList(batches: item.batches),

              // ── Pie de Tarjeta ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                child: Row(
                  children: [
                    const Icon(
                      Icons.flag_outlined,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Punto de reorden: ${item.reorderPoint} uds.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: onTap,
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Variantes',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        context.push(
                          '/admin/kardex?productId=${item.productId}&variantId=${item.variantId}&productName=${Uri.encodeComponent(item.productName)}&variantName=${Uri.encodeComponent(item.attrsText)}',
                        );
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.receipt_long_rounded,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Kárdex',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (item.usesBatches)
                      _Badge(
                        icon: Icons.batch_prediction_rounded,
                        label:
                            '${item.batches.length} lote${item.batches.length != 1 ? 's' : ''}',
                        color: AppColors.primary,
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

class _BatchMiniList extends StatelessWidget {
  final List<InventoryBatchItem> batches;
  const _BatchMiniList({required this.batches});

  @override
  Widget build(BuildContext context) {
    final active = batches.where((b) => b.availableQuantity > 0).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            active.map((b) {
              Color expiryColor = AppColors.textSecondary;
              String expiryLabel = 'Sin vencimiento';

              if (b.expiryDate != null) {
                final expiry = DateTime.tryParse(b.expiryDate!);
                if (expiry != null) {
                  final diff = expiry.difference(DateTime.now()).inDays;
                  if (diff < 0) {
                    expiryColor = AppColors.danger;
                    expiryLabel = 'Vencido';
                  } else if (diff <= 30) {
                    expiryColor = AppColors.warning;
                    expiryLabel = 'Vence en $diff días';
                  } else {
                    expiryColor = AppColors.success;
                    expiryLabel =
                        '${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}';
                  }
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: expiryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      b.batchNumber == 'DEFAULT'
                          ? 'Sin lote'
                          : 'Lote ${b.batchNumber}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${b.availableQuantity} uds.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    if (b.warehouseName != null) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '· ${b.warehouseName}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    Text(
                      expiryLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: expiryColor,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
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
