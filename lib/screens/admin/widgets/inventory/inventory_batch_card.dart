import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:inventory_store_app/models/inventory_stock_models.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class InventoryBatchCard extends StatelessWidget {
  final InventoryBatchItem batch;

  const InventoryBatchCard({super.key, required this.batch});

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
        border: Border(left: BorderSide(color: statusColor, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Encabezado ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child:
                        batch.imageUrl != null && batch.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                              imageUrl: batch.imageUrl!,
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) => Container(
                                    color: Colors.grey.shade50,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => Container(
                                    color: Colors.grey.shade50,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      size: 20,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                            )
                            : Container(
                              color: Colors.grey.shade50,
                              child: Icon(
                                Icons.inventory_2_outlined,
                                size: 22,
                                color: Colors.grey.shade400,
                              ),
                            ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        batch.productName ??
                            'Producto ${batch.productId.substring(0, 8)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (batch.variantAttrs != null &&
                              batch.variantAttrs!.isNotEmpty &&
                              batch.variantAttrs != 'Única')
                            batch.variantAttrs!,
                          if (batch.sku != null && batch.sku!.isNotEmpty)
                            'SKU: ${batch.sku}',
                          if (batch.warehouseName != null) batch.warehouseName!,
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 13, color: statusColor),
                      const SizedBox(width: 4),
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

            const SizedBox(height: 10),

            // ── Pills de detalle ──
            Wrap(
              spacing: 6,
              runSpacing: 6,
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
                  label: '${batch.availableQuantity} uds.',
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
                    label: 'Vence: ${batch.expiryDate!.substring(0, 10)}',
                    color: statusColor,
                  ),
              ],
            ),
          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
