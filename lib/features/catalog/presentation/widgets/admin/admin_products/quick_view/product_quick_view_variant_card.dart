import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_stock_batch_model.dart';

/// Tarjeta individual para listar una variante dentro de la Ficha Rápida.
class ProductQuickViewVariantCard extends StatelessWidget {
  final ProductVariantEntity variant;
  final String? productName;
  final int index;
  final bool isSingleVariant;
  final int productStock;
  final List<WarehouseStockBatchModel>? batches;

  const ProductQuickViewVariantCard({
    super.key,
    required this.variant,
    this.productName,
    this.index = 0,
    required this.isSingleVariant,
    required this.productStock,
    this.batches,
  });

  String _title() {
    final sku = variant.sku?.trim();
    final hasSku = sku != null && sku.isNotEmpty && sku != 'N/A';
    if (variant.attributeValues.isNotEmpty) return variant.label;
    if (hasSku) return sku;
    if (!isSingleVariant) return 'Variante #${index + 1}';
    final name = productName?.trim();
    return (name != null && name.isNotEmpty) ? name : 'Producto Base';
  }

  /// Stock de la variante. Devuelve null cuando NO se puede saber
  /// (así no mostramos un "Agotado" falso).
  int? _variantStock() {
    // Una sola variante: su stock ES el stock del producto.
    if (isSingleVariant) return productStock;

    // Varias variantes: solo podemos calcularlo si hay lotes.
    if (batches != null && batches!.isNotEmpty) {
      return batches!
          .where((b) => b.variantId == variant.id)
          .fold<double>(0, (s, b) => s + b.availableQuantity)
          .toInt();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final title = _title();
    final sku = variant.sku?.trim();
    final showSku =
        sku != null && sku.isNotEmpty && sku != 'N/A' && sku != title;

    final stock = _variantStock();
    final isOut = stock != null && stock <= 0;

    final salePrice = variant.salePrice;
    final cost = variant.unitCost;
    final wholesale = variant.wholesalePrice;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color:
                    variant.isActive ? AppColors.success : AppColors.textMuted,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Título + SKU + chip de stock (en Wrap: no desborda en móvil)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (showSku)
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
                if (stock != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isOut
                              ? AppColors.danger.withValues(alpha: 0.08)
                              : AppColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      isOut ? 'Agotado' : '$stock unid.',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isOut ? AppColors.danger : AppColors.tealDark,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Precios
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                salePrice != null
                    ? 'S/ ${salePrice.toStringAsFixed(2)}'
                    : 'Sin precio',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
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
              if (wholesale != null)
                Text(
                  'Mayoreo: S/ ${wholesale.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.tealDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
