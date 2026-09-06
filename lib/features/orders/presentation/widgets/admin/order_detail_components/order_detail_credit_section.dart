import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_section_card.dart';

class OrderDetailCreditSection extends StatelessWidget {
  final Map<String, dynamic>? creditInfo;
  final String? customerId;

  const OrderDetailCreditSection({
    super.key,
    required this.creditInfo,
    required this.customerId,
  });

  @override
  Widget build(BuildContext context) {
    if (customerId == null) {
      return const OrderDetailSectionCard(
        title: 'Crédito del Cliente',
        child: Text(
          'Sin cliente asignado para mostrar crédito.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    if (creditInfo == null) {
      return const OrderDetailSectionCard(
        title: 'Crédito del Cliente',
        child: Text(
          'Este cliente no tiene línea de crédito registrada.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      );
    }

    final isActive = creditInfo!['is_active'] == true;
    final limit = (creditInfo!['credit_limit'] as num).toDouble();
    final debt = (creditInfo!['current_debt'] as num).toDouble();
    final available = (limit - debt).clamp(0.0, double.infinity);

    return OrderDetailSectionCard(
      title: 'Línea de Crédito',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isActive ? AppColors.success.withValues(alpha: 0.1) : AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? AppColors.success.withValues(alpha: 0.25) : AppColors.error.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          isActive ? 'Crédito activo' : 'Inactivo',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: isActive ? AppColors.successDark : AppColors.error,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CreditStatCell(
              label: 'Límite Global',
              value: 'S/ ${limit.toStringAsFixed(2)}',
              icon: Icons.account_balance_wallet_outlined,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CreditStatCell(
              label: 'Deuda Total',
              value: 'S/ ${debt.toStringAsFixed(2)}',
              valueColor: debt > 0 ? AppColors.error : AppColors.teal,
              bold: debt > 0,
              icon: Icons.credit_score_rounded,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CreditStatCell(
              label: 'Disponible',
              value: 'S/ ${available.toStringAsFixed(2)}',
              valueColor: available > 0 ? AppColors.teal : AppColors.textMuted,
              icon: Icons.check_circle_outline_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditStatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  final IconData? icon;

  const _CreditStatCell({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: valueColor ?? AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}
