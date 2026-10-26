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
  final double taxAmount;
  final double subtotalAmount;
  final String currencySymbol;
  final String currencyCode;
  final double exchangeRate;

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
    this.taxAmount = 0.0,
    this.subtotalAmount = 0.0,
    this.currencySymbol = 'S/',
    this.currencyCode = 'PEN',
    this.exchangeRate = 1.0,
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
    bool isDark = false,
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
                    color:
                        isEmphasized
                            ? (isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary)
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary),
                  ),
                ),
                if (hint != null)
                  Text(
                    hint,
                    style: TextStyle(
                      fontSize: 10,
                      color:
                          isDark
                              ? const Color(0xFFFBBF24)
                              : AppColors.amberDark,
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
              color:
                  valueColor ??
                  (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
              letterSpacing: isEmphasized ? -0.3 : 0,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final capApplied = _rawDiscount > _appliedDiscount;
    final sym = currencySymbol.trim().isEmpty ? 'S/' : currencySymbol;

    return OrderDetailSectionCard(
      title: 'Resumen total',
      child: Column(
        children: [
          if (taxAmount > 0) ...[
            _buildRow(
              'Op. Gravada',
              '$sym ${(subtotalAmount > 0 ? subtotalAmount : (subtotal - taxAmount)).toStringAsFixed(2)}',
              isDark: isDark,
            ),
            _buildRow(
              'I.G.V. (18%)',
              '$sym ${taxAmount.toStringAsFixed(2)}',
              isDark: isDark,
            ),
          ] else
            _buildRow(
              'Subtotal',
              '$sym ${subtotal.toStringAsFixed(2)}',
              isDark: isDark,
            ),
          if (pointsUsed > 0) ...[
            _buildRow('Monedas usadas', '$pointsUsed monedas', isDark: isDark),
            _buildRow(
              'Descuento por monedas',
              '- $sym ${_appliedDiscount.toStringAsFixed(2)}',
              valueColor:
                  isDark ? const Color(0xFF34D399) : AppColors.successDark,
              isDark: isDark,
              hint:
                  capApplied
                      ? 'Cap 50% aplicado ($sym ${_rawDiscount.toStringAsFixed(2)} → $sym ${_appliedDiscount.toStringAsFixed(2)})'
                      : null,
            ),
          ],
          if (discountAmount > 0)
            _buildRow(
              'Descuento adicional',
              '- $sym ${discountAmount.toStringAsFixed(2)}',
              valueColor:
                  isDark ? const Color(0xFF34D399) : AppColors.successDark,
              isDark: isDark,
            ),
          Divider(
            height: 16,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
          _buildRow(
            'Total final',
            '$sym ${_totalFinal.toStringAsFixed(2)}',
            isEmphasized: true,
            valueColor: isDark ? const Color(0xFF2DD4BF) : AppColors.teal,
            isDark: isDark,
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
              isDark: isDark,
            ),
        ],
      ),
    );
  }
}
