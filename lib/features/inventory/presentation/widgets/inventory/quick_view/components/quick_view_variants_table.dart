import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_shimmer.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_variant_entity.dart';

/// Lista vertical de todas las variantes del producto con métricas de stock y acceso a Kárdex.
class QuickViewVariantsTable extends StatelessWidget {
  final List<ProductVariantEntity> variants;
  final String activeVariantId;
  final bool isLoading;
  final int totalProductStock;
  final String defaultProductName;
  final double defaultSalePrice;
  final double defaultUnitCost;
  final int Function(String variantId) stockCalculator;
  final ValueChanged<String> onVariantSelected;
  final void Function(ProductVariantEntity variant, String displayTitle)
  onOpenKardex;

  const QuickViewVariantsTable({
    super.key,
    required this.variants,
    required this.activeVariantId,
    required this.isLoading,
    required this.totalProductStock,
    required this.defaultProductName,
    required this.defaultSalePrice,
    required this.defaultUnitCost,
    required this.stockCalculator,
    required this.onVariantSelected,
    required this.onOpenKardex,
  });

  @override
  Widget build(BuildContext context) {
    if (variants.length <= 1 && !isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.list_alt_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  isLoading && variants.isEmpty
                      ? 'Variantes del producto...'
                      : 'Todas las variantes (${variants.length})',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Text(
              'Total prod: $totalProductStock uds.',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.tealDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (isLoading && variants.isEmpty)
          Column(
            children: List.generate(
              3,
              (idx) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Row(
                    children: [
                      AppShimmer(width: 8, height: 8, borderRadius: 4),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AppShimmer(width: 120, height: 14, borderRadius: 4),
                            SizedBox(height: 4),
                            AppShimmer(width: 80, height: 10, borderRadius: 4),
                          ],
                        ),
                      ),
                      AppShimmer(width: 60, height: 16, borderRadius: 4),
                    ],
                  ),
                ),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: variants.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final v = variants[index];
              final isSelected = v.id == activeVariantId;
              final vStock = stockCalculator(v.id);
              final displayTitle =
                  v.attributeValues.isNotEmpty
                      ? v.label
                      : (v.sku?.isNotEmpty == true && v.sku != 'N/A'
                          ? v.sku!
                          : (variants.length == 1
                              ? defaultProductName
                              : 'Variante #${index + 1}'));

              return _QuickViewVariantRow(
                title: displayTitle,
                sku: v.sku,
                barcode: v.barcode,
                salePrice: v.salePrice ?? defaultSalePrice,
                unitCost: v.unitCost ?? defaultUnitCost,
                stock: vStock,
                isActive: v.isActive,
                isSelected: isSelected,
                onSelect: () {
                  AppFeedbackService.selectionClick();
                  onVariantSelected(v.id);
                },
                onOpenKardex: () => onOpenKardex(v, displayTitle),
              );
            },
          ),
      ],
    );
  }
}

class _QuickViewVariantRow extends StatelessWidget {
  final String title;
  final String? sku;
  final String? barcode;
  final double salePrice;
  final double unitCost;
  final int stock;
  final bool isActive;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onOpenKardex;

  const _QuickViewVariantRow({
    required this.title,
    this.sku,
    this.barcode,
    required this.salePrice,
    required this.unitCost,
    required this.stock,
    required this.isActive,
    required this.isSelected,
    required this.onSelect,
    required this.onOpenKardex,
  });

  @override
  Widget build(BuildContext context) {
    final isOut = stock <= 0;
    final isLow = stock > 0 && stock <= 5;

    Color stockBg;
    Color stockColor;
    String stockLabel;

    if (isOut) {
      stockBg = AppColors.danger.withValues(alpha: 0.08);
      stockColor = AppColors.danger;
      stockLabel = 'Agotado';
    } else if (isLow) {
      stockBg = AppColors.warning.withValues(alpha: 0.1);
      stockColor = AppColors.warningDark;
      stockLabel = '$stock uds.';
    } else {
      stockBg = AppColors.teal.withValues(alpha: 0.1);
      stockColor = AppColors.tealDark;
      stockLabel = '$stock uds.';
    }

    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.primary.withValues(alpha: 0.04)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Dot activo / seleccionado
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppColors.primary
                        : (isActive ? AppColors.success : AppColors.textMuted),
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
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
                            color:
                                isSelected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Activa',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if ((sku != null && sku!.isNotEmpty && title != sku) ||
                      (barcode != null && barcode!.isNotEmpty))
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (sku != null && sku!.isNotEmpty && title != sku)
                            Text(
                              'SKU: $sku',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                                fontFamily: 'monospace',
                              ),
                            ),
                          if (barcode != null && barcode!.isNotEmpty) ...[
                            if (sku != null && sku!.isNotEmpty && title != sku)
                              const Text(
                                ' · ',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            const Icon(
                              Icons.barcode_reader,
                              size: 11,
                              color: AppColors.tealDark,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              barcode!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.tealDark,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Stock Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: stockBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                stockLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: stockColor,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Precios
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'S/ ${salePrice.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'Costo: S/ ${unitCost.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),

            const SizedBox(width: 6),
            // Botón directo a Kárdex
            Tooltip(
              message: 'Ver movimientos de esta variante en Kárdex',
              child: IconButton(
                icon: const Icon(Icons.receipt_long_rounded, size: 16),
                color: AppColors.textSecondary,
                hoverColor: AppColors.primary.withValues(alpha: 0.08),
                onPressed: onOpenKardex,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
