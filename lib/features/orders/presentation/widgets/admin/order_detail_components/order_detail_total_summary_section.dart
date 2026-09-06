import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_section_card.dart';

class OrderDetailTotalSummarySection extends StatelessWidget {
  final double subtotal;
  final int pointsUsed;
  final int pointsEarned;
  final double pointsToSolesRatio;
  final double discountAmount;
  final bool isCompleted;
  final bool isCredit;
  final bool isLoyaltyEnabled;

  const OrderDetailTotalSummarySection({
    super.key,
    required this.subtotal,
    required this.pointsUsed,
    required this.pointsEarned,
    required this.pointsToSolesRatio,
    this.discountAmount = 0.0,
    this.isCompleted = true,
    this.isCredit = false,
    required this.isLoyaltyEnabled,
  });

  double get _rawDiscount => pointsUsed * pointsToSolesRatio;
  double get _appliedDiscount {
    final maxDiscount = subtotal * 0.5;
    return _rawDiscount > maxDiscount ? maxDiscount : _rawDiscount;
  }

  double get _totalFinal {
    final total = subtotal - _appliedDiscount - discountAmount;
    return total < 0 ? 0 : total;
  }

  Widget _buildRow(
    String label,
    String value, {
    bool isEmphasized = false,
    Color? valueColor,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isEmphasized ? FontWeight.w700 : FontWeight.w500,
                    color: isEmphasized ? AppColors.textPrimary : AppColors.textSecondary,
                  ),
                ),
                if (hint != null)
                  Text(
                    hint,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.amberDark,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isEmphasized ? 16 : 13,
              fontWeight: isEmphasized ? FontWeight.w900 : FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
              letterSpacing: isEmphasized ? -0.3 : 0,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final capApplied = _rawDiscount > _appliedDiscount;
    return OrderDetailSectionCard(
      title: 'Resumen total',
      child: Column(
        children: [
          _buildRow('Subtotal', 'S/ ${subtotal.toStringAsFixed(2)}'),
          if (pointsUsed > 0) ...[
            _buildRow('Monedas usadas', '$pointsUsed monedas'),
            _buildRow(
              'Descuento por monedas',
              '- S/ ${_appliedDiscount.toStringAsFixed(2)}',
              valueColor: AppColors.successDark,
              hint:
                  capApplied
                      ? 'Cap 50% aplicado (S/ ${_rawDiscount.toStringAsFixed(2)} → S/ ${_appliedDiscount.toStringAsFixed(2)})'
                      : null,
            ),
          ],
          if (discountAmount > 0)
            _buildRow(
              'Descuento adicional',
              '- S/ ${discountAmount.toStringAsFixed(2)}',
              valueColor: AppColors.successDark,
            ),
          const Divider(height: 16, color: AppColors.border),
          _buildRow(
            'Total final',
            'S/ ${_totalFinal.toStringAsFixed(2)}',
            isEmphasized: true,
            valueColor: AppColors.teal,
          ),
          const SizedBox(height: 6),
          if (isLoyaltyEnabled || pointsEarned > 0)
            _buildRow(
              !isLoyaltyEnabled
                  ? 'Monedas ganadas'
                  : ((isCompleted && !isCredit)
                      ? 'Monedas ganadas'
                      : 'Pendientes de otorgar'),
              '$pointsEarned monedas',
            ),
        ],
      ),
    );
  }
}
