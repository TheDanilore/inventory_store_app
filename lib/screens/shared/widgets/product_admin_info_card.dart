// ─── ADMIN INFO CARD ─────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class ProductAdminInfoCard extends StatelessWidget {
  final double unitCost;
  final double profit;
  final double margin;
  final double? wholesalePrice;
  final int wholesaleMinQuantity;
  final int reorderPoint;

  const ProductAdminInfoCard({
    super.key,
    required this.unitCost,
    required this.profit,
    required this.margin,
    required this.wholesalePrice,
    required this.wholesaleMinQuantity,
    required this.reorderPoint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppColors.radiusXl),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          _AdminRow(
            Icons.receipt_long_rounded,
            const Color(0xFFF59E0B),
            'Costo unitario',
            'S/ ${unitCost.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          _AdminRow(
            Icons.trending_up_rounded,
            AppColors.success,
            'Ganancia estim.',
            'S/ ${profit.toStringAsFixed(2)}',
            badge: '${margin.toStringAsFixed(1)}%',
            valueColor: AppColors.success,
          ),
          if (wholesalePrice != null) ...[
            const SizedBox(height: 8),
            _AdminRow(
              Icons.people_rounded,
              AppColors.amber,
              'Precio mayor',
              'S/ ${wholesalePrice!.toStringAsFixed(2)}',
              badge: 'x$wholesaleMinQuantity',
            ),
          ],
          const SizedBox(height: 8),
          _AdminRow(
            Icons.warning_amber_rounded,
            AppColors.danger,
            'Pto. reorden',
            '$reorderPoint unds.',
          ),
        ],
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
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
