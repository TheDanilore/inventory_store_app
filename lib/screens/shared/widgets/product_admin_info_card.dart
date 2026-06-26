// ─── ADMIN INFO CARD ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

import 'package:provider/provider.dart';
import 'package:inventory_store_app/providers/shared/product_detail_provider.dart';

class ProductAdminInfoCard extends StatelessWidget {
  const ProductAdminInfoCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductDetailProvider>();
    if (!provider.isAdmin) return const SizedBox.shrink();

    final cost =
        ((provider.selectedVariant?.unitCost ?? 0) > 0)
            ? provider.selectedVariant!.unitCost!
            : provider.product.unitCost;
    final wPrice = provider.baseWholesalePrice;
    final rPoint = provider.selectedVariant?.reorderPoint ?? 0;

    final retailProfitUnit = provider.effectivePrice - cost;
    final retailMargin =
        (provider.effectivePrice > 0)
            ? (retailProfitUnit / provider.effectivePrice) * 100
            : 0.0;

    final wholesaleProfitUnit = wPrice != null ? wPrice - cost : 0.0;
    final wholesaleMargin =
        (wPrice != null && wPrice > 0)
            ? (wholesaleProfitUnit / wPrice) * 100
            : 0.0;

    final effectiveStock = provider.effectiveStock;
    final projectedRetail = retailProfitUnit * effectiveStock;
    final projectedWholesale = wholesaleProfitUnit * effectiveStock;
    return Material(
      color: const Color(0xFFF8FAFC),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedIconColor: AppColors.slate,
          iconColor: AppColors.slate,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.slate.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: AppColors.slate,
                  size: 16,
                ),
              ),
              const SizedBox(width: 9),
              const Text(
                'Info interna',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.slate,
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),
                  _AdminRow(
                    Icons.receipt_long_rounded,
                    const Color(0xFFF59E0B),
                    'Costo unitario',
                    'S/ ${cost.toStringAsFixed(2)}',
                  ),
                  const SizedBox(height: 8),
                  _AdminRow(
                    Icons.trending_up_rounded,
                    AppColors.success,
                    'G. Minorista (und)',
                    'S/ ${retailProfitUnit.toStringAsFixed(2)}',
                    badge: '${retailMargin.toStringAsFixed(1)}%',
                    valueColor: AppColors.success,
                  ),
                  if (wPrice != null) ...[
                    const SizedBox(height: 8),
                    _AdminRow(
                      Icons.people_rounded,
                      AppColors.primary,
                      'G. Mayorista (und)',
                      'S/ ${wholesaleProfitUnit.toStringAsFixed(2)}',
                      badge: '${wholesaleMargin.toStringAsFixed(1)}%',
                      valueColor: AppColors.primary,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _AdminRow(
                    Icons.warning_amber_rounded,
                    AppColors.danger,
                    'Pto. reorden',
                    '$rPoint unds.',
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),
                  _AdminRow(
                    Icons.bar_chart_rounded,
                    AppColors.teal,
                    'Proy. Minorista',
                    'S/ ${projectedRetail.toStringAsFixed(2)}',
                    badge: 'Todo el stock',
                  ),
                  if (wPrice != null) ...[
                    const SizedBox(height: 8),
                    _AdminRow(
                      Icons.bar_chart_rounded,
                      Colors.blue,
                      'Proy. Mayorista',
                      'S/ ${projectedWholesale.toStringAsFixed(2)}',
                      badge: 'Todo el stock',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? badge;
  final Color? valueColor;
  const _AdminRow(
    this.icon,
    this.iconColor,
    this.label,
    this.value, {
    this.badge,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.slateLight,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              badge!,
              style: const TextStyle(
                fontSize: 9,
                color: AppColors.slate,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
