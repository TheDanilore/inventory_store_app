import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';

/// Sección de desglose de lotes de la variante activa con semántica de fechas de caducidad.
class QuickViewBatchesSection extends StatelessWidget {
  final bool usesBatches;
  final bool isDefaultVariantSelected;
  final List<InventoryBatchItem> batches;
  final int activeVariantStock;

  const QuickViewBatchesSection({
    super.key,
    required this.usesBatches,
    required this.isDefaultVariantSelected,
    required this.batches,
    required this.activeVariantStock,
  });

  Widget _buildBatchRow(InventoryBatchItem batch) {
    Color badgeColor = AppColors.teal;
    String badgeText = 'Normal';
    if (batch.status == 'vencido') {
      badgeColor = AppColors.danger;
      badgeText = 'Vencido';
    } else if (batch.status == 'critico') {
      badgeColor = AppColors.warning;
      badgeText = 'Crítico (${batch.daysRemaining}d)';
    } else if (batch.status == 'proximo') {
      badgeColor = AppColors.accent;
      badgeText = 'Próximo (${batch.daysRemaining}d)';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.qr_code_2_rounded,
            size: 15,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lote: ${batch.batchNumber}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                    color: AppColors.textPrimary,
                  ),
                ),
                if (batch.warehouseName != null)
                  Text(
                    batch.warehouseName!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              badgeText,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${batch.availableQuantity} uds.',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!usesBatches) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.batch_prediction_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6),
                Text(
                  'Lotes de esta variante',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            if (isDefaultVariantSelected)
              Text(
                '${batches.length} lote${batches.length != 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (isDefaultVariantSelected && batches.isNotEmpty)
          Column(
            children:
                batches.map((batch) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _buildBatchRow(batch),
                  );
                }).toList(),
          )
        else if (activeVariantStock <= 0)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                SizedBox(width: 8),
                Text(
                  'Sin lotes activos en el almacén seleccionado',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: AppColors.tealDark,
                ),
                SizedBox(width: 8),
                Text(
                  'Lotes registrados en sistema ($activeVariantStock uds. disponibles)',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}
