import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_stock_batch_model.dart';

/// Tarjeta individual para listar una variante de producto dentro del Quick View Sheet.
class ProductQuickViewVariantCard extends StatelessWidget {
  final ProductVariantEntity variant;
  final int index;
  final bool isSingleVariant;
  final int productStock;
  final List<WarehouseStockBatchModel>? batches;

  const ProductQuickViewVariantCard({
    super.key,
    required this.variant,
    this.index = 0,
    required this.isSingleVariant,
    required this.productStock,
    this.batches,
  });

  @override
  Widget build(BuildContext context) {
    String displayTitle;
    if (variant.attributeValues.isNotEmpty) {
      displayTitle = variant.label;
    } else if (variant.sku != null && variant.sku!.trim().isNotEmpty) {
      displayTitle = variant.sku!;
    } else if (!isSingleVariant) {
      displayTitle = 'Variante #${index + 1}';
    } else {
      displayTitle = 'Variante Estándar';
    }

    final salePrice = variant.salePrice;
    final cost = variant.unitCost;
    final wholesalePrice = variant.wholesalePrice;
    final sku = variant.sku;

    // Calcular stock de la variante si hay lotes disponibles
    final int variantStock;
    if (batches != null && batches!.isNotEmpty) {
      variantStock = batches!
          .where((b) => b.variantId == variant.id)
          .fold<double>(0, (s, b) => s + b.availableQuantity)
          .toInt();
    } else {
      variantStock = isSingleVariant ? productStock : 0;
    }

    final isOut = variantStock <= 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Dot activo
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: variant.isActive ? AppColors.success : AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),

          // Label y SKU
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayTitle,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Micro-chip de stock de variante
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color:
                            isOut
                                ? AppColors.danger.withValues(alpha: 0.08)
                                : AppColors.teal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isOut ? 'Agotado' : '$variantStock unid.',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isOut ? AppColors.danger : AppColors.tealDark,
                        ),
                      ),
                    ),
                  ],
                ),
                if (sku != null && sku.isNotEmpty && displayTitle != sku)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'SKU: $sku',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Precios
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                salePrice != null
                    ? 'S/ ${salePrice.toStringAsFixed(2)}'
                    : 'Sin precio',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (cost != null)
                Text(
                  'Costo: S/ ${cost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              if (wholesalePrice != null)
                Text(
                  'Mayoreo: S/ ${wholesalePrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.tealDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
