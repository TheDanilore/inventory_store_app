import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class ProductFinancialBentoGrid extends StatelessWidget {
  final double effectivePrice;
  final double baseSalePrice;
  final double? baseWholesalePrice;
  final int baseWholesaleMinQty;
  final double cost;
  final int effectiveStock;
  final int reorderPoint;
  final bool isCompact;

  const ProductFinancialBentoGrid({
    super.key,
    required this.effectivePrice,
    required this.baseSalePrice,
    this.baseWholesalePrice,
    required this.baseWholesaleMinQty,
    required this.cost,
    required this.effectiveStock,
    this.reorderPoint = 0,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final retailProfit = effectivePrice > cost ? effectivePrice - cost : 0.0;
    final retailMargin =
        effectivePrice > 0 ? (retailProfit / effectivePrice) * 100 : 0.0;

    final wholesaleProfit =
        (baseWholesalePrice != null && baseWholesalePrice! > cost)
            ? baseWholesalePrice! - cost
            : 0.0;
    final wholesaleMargin =
        (baseWholesalePrice != null && baseWholesalePrice! > 0)
            ? (wholesaleProfit / baseWholesalePrice!) * 100
            : 0.0;

    final totalInventoryValue = effectiveStock * cost;
    final isLowStock = reorderPoint > 0 && effectiveStock <= reorderPoint;

    final cards = [
      // 1. PRECIO DE VENTA Y TARIFA B2B
      _buildBentoCard(
        title: 'PRECIO DE VENTA',
        icon: Icons.payments_outlined,
        iconColor: AppColors.primary,
        value: 'S/ ${effectivePrice.toStringAsFixed(2)}',
        secondaryWidget:
            baseWholesalePrice != null
                ? Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.discount_outlined,
                        size: 13,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          isCompact
                              ? 'May. (x$baseWholesaleMinQty+): S/ ${baseWholesalePrice!.toStringAsFixed(2)}'
                              : 'Mayoreo (x$baseWholesaleMinQty+): S/ ${baseWholesalePrice!.toStringAsFixed(2)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                : const Text(
                  'Tarifa estándar única',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
      ),

      // 2. COSTO UNITARIO Y UTILIDAD BRUTA
      _buildBentoCard(
        title: 'COSTO Y GANANCIA',
        icon: Icons.receipt_long_outlined,
        iconColor: const Color(0xFF0284C7),
        value: 'S/ ${cost.toStringAsFixed(2)}',
        subValueLabel: 'Costo base unitario',
        secondaryWidget: Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.successLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.trending_up_rounded,
                size: 14,
                color: AppColors.successDark,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  isCompact
                      ? '+S/ ${retailProfit.toStringAsFixed(2)}/u'
                      : 'Utilidad: +S/ ${retailProfit.toStringAsFixed(2)}/und',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.successDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // 3. MARGEN DE RENTABILIDAD (%)
      _buildBentoCard(
        title: 'MARGEN BRUTO',
        icon: Icons.pie_chart_outline_rounded,
        iconColor:
            retailMargin >= 30
                ? AppColors.success
                : retailMargin >= 15
                ? AppColors.amber
                : AppColors.danger,
        value: '${retailMargin.toStringAsFixed(1)}%',
        subValueLabel:
            baseWholesalePrice != null
                ? 'Mayoreo: ${wholesaleMargin.toStringAsFixed(1)}%'
                : 'Margen sobre venta',
        secondaryWidget: Container(
          margin: const EdgeInsets.only(top: 8),
          height: 6,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (retailMargin / 100).clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color:
                    retailMargin >= 30
                        ? AppColors.success
                        : retailMargin >= 15
                        ? AppColors.amber
                        : AppColors.danger,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ),

      // 4. VALUACIÓN DE INVENTARIO Y SALUD DE STOCK
      _buildBentoCard(
        title: 'CAPITAL EN STOCK',
        icon: Icons.inventory_2_outlined,
        iconColor: isLowStock ? AppColors.amberDark : AppColors.teal,
        value: 'S/ ${totalInventoryValue.toStringAsFixed(2)}',
        subValueLabel: '$effectiveStock unidades en almacén',
        borderColor: isLowStock ? AppColors.amber : null,
        borderWidth: isLowStock ? 1.5 : 1.0,
        bgColor:
            isLowStock ? AppColors.amberLight.withValues(alpha: 0.15) : null,
        secondaryWidget:
            isLowStock
                ? Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.amberLight,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 13,
                        color: AppColors.amberDark,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          isCompact
                              ? 'Reorden: $reorderPoint'
                              : 'Punto de Reorden: $reorderPoint',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.amberDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                : Container(
                  margin: const EdgeInsets.only(top: 8),
                  child: Text(
                    reorderPoint > 0
                        ? 'Pto. reorden: $reorderPoint unds'
                        : 'Stock sin alerta',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
      ),
    ];

    if (isCompact) {
      // 2x2 grid for Tablet / Mobile with sufficient vertical extent to prevent layout overflow
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 154,
        ),
        itemCount: cards.length,
        itemBuilder: (context, index) => cards[index],
      );
    }

    // 4 columns horizontal bento row for Desktop
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i < cards.length - 1) const SizedBox(width: 14),
        ],
      ],
    );
  }

  Widget _buildBentoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String value,
    String? subValueLabel,
    Widget? secondaryWidget,
    Color? borderColor,
    double borderWidth = 1.0,
    Color? bgColor,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 16,
        vertical: isCompact ? 11 : 16,
      ),
      decoration: BoxDecoration(
        color: bgColor ?? Colors.white,
        borderRadius: BorderRadius.circular(AppColors.radius),
        border: Border.all(
          color: borderColor ?? AppColors.border,
          width: borderWidth,
        ),
        boxShadow: AppColors.cardShadow(opacity: 0.02),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 15, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                  height: 1.1,
                ),
              ),
              if (subValueLabel != null) ...[
                const SizedBox(height: 3),
                Text(
                  subValueLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
          if (secondaryWidget != null) secondaryWidget,
        ],
      ),
    );
  }
}
