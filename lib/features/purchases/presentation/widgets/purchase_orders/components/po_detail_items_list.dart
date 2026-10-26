import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/core/widgets/product_item_card.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_item_entity.dart';

/// Lista de productos de la orden de compra optimizada con Zero-Shimmer sobre caché
/// y barras de progreso visual de recepción por producto.
class PODetailItemsList extends StatelessWidget {
  final List<PurchaseOrderItemEntity>? items;
  final bool isLoading;

  const PODetailItemsList({
    super.key,
    required this.items,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final hasCachedItems = items != null && items!.isNotEmpty;

    // Zero-Shimmer Policy: Shimmer SOLAMENTE en Cold Start si no hay datos en memoria/caché
    if (isLoading && !hasCachedItems) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder:
            (_, _) => const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: AppShimmer(
                width: double.infinity,
                height: 76,
                borderRadius: 12,
              ),
            ),
      );
    }

    if (items == null || items!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No hay productos en esta orden.',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return Column(
      children: List.generate(items!.length, (index) {
        final item = items![index];
        final isFullyReceived = item.fullyReceived;
        final progress =
            item.quantityOrdered > 0
                ? item.quantityReceived / item.quantityOrdered
                : 0.0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ProductItemCard(
            imageUrl: item.imageUrl,
            productName: item.productName ?? '—',
            variantLabel: item.variantAttrs,
            progressWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    backgroundColor: AppColors.border,
                    color:
                        isFullyReceived ? AppColors.success : AppColors.warning,
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Recibido: ${item.quantityReceived.toInt()} / ${item.quantityOrdered.toInt()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color:
                        isFullyReceived ? AppColors.success : AppColors.warning,
                  ),
                ),
              ],
            ),
            trailing: ItemPriceColumnTrailing(
              quantityText: '${item.quantityOrdered.toInt()} uds.',
              unitCostText: 'S/ ${item.unitCost.toStringAsFixed(2)} c/u',
              subtotalText: 'S/ ${item.subtotal.toStringAsFixed(2)}',
            ),
            animationDelay: Duration(milliseconds: 40 * index),
          ),
        );
      }),
    );
  }
}
