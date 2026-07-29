import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:go_router/go_router.dart';

class InventoryBatchCard extends StatelessWidget {
  final InventoryBatchItem batch;
  final bool isSelected;
  final VoidCallback? onTap;

  const InventoryBatchCard({
    super.key,
    required this.batch,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    switch (batch.status) {
      case 'vencido':
        statusColor = AppColors.danger;
        statusLabel = 'VENCIDO';
        statusIcon = Icons.block_rounded;
        break;
      case 'critico':
        statusColor = AppColors.warning;
        final d = batch.daysRemaining ?? 0;
        statusLabel =
            d == 0
                ? 'HOY'
                : d == 1
                ? 'MAÑANA'
                : 'EN $d DÍAS';
        statusIcon = Icons.warning_amber_rounded;
        break;
      case 'proximo':
        statusColor = Colors.orange.shade400;
        statusLabel = 'EN ${batch.daysRemaining} DÍAS';
        statusIcon = Icons.schedule_rounded;
        break;
      case 'normal':
        statusColor = AppColors.success;
        final expiry = DateTime.tryParse(batch.expiryDate ?? '');
        statusLabel =
            expiry != null
                ? '${expiry.day.toString().padLeft(2, '0')}/'
                    '${expiry.month.toString().padLeft(2, '0')}/'
                    '${expiry.year}'
                : 'NORMAL';
        statusIcon = Icons.check_circle_rounded;
        break;
      default:
        statusColor = AppColors.textSecondary;
        statusLabel = 'SIN VTO.';
        statusIcon = Icons.remove_circle_outline_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.border,
          width: isSelected ? 1.5 : 1,
        ),
        boxShadow: AppColors.cardShadow(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: statusColor, width: 5)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap:
                  onTap ??
                  () {
                    context.go(
                      '/admin/product/${batch.productId}?variantId=${batch.variantId}',
                    );
                  },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Cabecera de Lote ──
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child:
                                batch.imageUrl != null &&
                                        batch.imageUrl!.isNotEmpty
                                    ? CachedNetworkImage(
                                      imageUrl: batch.imageUrl!,
                                      fit: BoxFit.cover,
                                      placeholder:
                                          (context, url) => Container(
                                            color: AppColors.background,
                                            child: const Center(
                                              child: SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                batch.productName ??
                                    'Producto ${batch.productId.substring(0, 8)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.textPrimary,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if (batch.variantAttrs != null &&
                                      batch.variantAttrs!.isNotEmpty &&
                                      batch.variantAttrs != 'Única')
                                    batch.variantAttrs!,
                                  if (batch.sku != null &&
                                      batch.sku!.isNotEmpty)
                                    'SKU: ${batch.sku}',
                                  if (batch.warehouseName != null)
                                    batch.warehouseName!,
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Badge de Estado del Lote
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 14, color: statusColor),
                              const SizedBox(width: 5),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // ── Píldoras de Detalle ──
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _DetailPill(
                          icon: Icons.numbers_rounded,
                          label:
                              batch.batchNumber == 'DEFAULT'
                                  ? 'Sin lote'
                                  : 'Lote: ${batch.batchNumber}',
                        ),
                        _DetailPill(
                          icon: Icons.inventory_2_rounded,
                          label: '${batch.availableQuantity} uds. disponibles',
                          color: AppColors.primary,
                        ),
                        if (batch.supplierName != null)
                          _DetailPill(
                            icon: Icons.business_rounded,
                            label: batch.supplierName!,
                          ),
                        if (batch.expiryDate != null)
                          _DetailPill(
                            icon: Icons.calendar_today_rounded,
                            label:
                                'Vence: ${batch.expiryDate!.substring(0, 10)}',
                            color: statusColor,
                          ),
                      ],
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

class _DetailPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DetailPill({
    required this.icon,
    required this.label,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
