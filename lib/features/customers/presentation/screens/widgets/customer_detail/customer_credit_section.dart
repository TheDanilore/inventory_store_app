import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/screens/widgets/customer_credits/register_payment_modal.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'customer_section_card.dart';

class CustomerCreditSection extends StatelessWidget {
  final double debt;
  final double limit;
  final bool isActive;
  final String creditId;
  final CustomerEntity customer;
  final List<CreditMovementEntity> movements;
  final VoidCallback onPaymentRegistered;

  const CustomerCreditSection({
    super.key,
    required this.debt,
    required this.limit,
    required this.isActive,
    required this.creditId,
    required this.customer,
    required this.movements,
    required this.onPaymentRegistered,
  });

  void _showRegisterPayment(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => RegisterPaymentModal(
            onSaved: onPaymentRegistered,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pct = limit > 0 ? (debt / limit).clamp(0.0, 1.0) : 0.0;
    final available = (limit - debt).clamp(0.0, double.infinity);
    final isRisk = pct >= 0.8;

    return CustomerSectionCard(
      title: 'LÃ­nea de CrÃ©dito',
      icon: Icons.credit_card_rounded,
      trailing:
          !isActive
              ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Inactivo',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _CreditStat(
                  label: 'Deuda',
                  value: 'S/ ${debt.toStringAsFixed(2)}',
                  color: debt > 0 ? AppColors.danger : AppColors.textMuted,
                ),
              ),
              Expanded(
                child: _CreditStat(
                  label: 'Disponible',
                  value: 'S/ ${available.toStringAsFixed(2)}',
                  color: isActive ? AppColors.success : AppColors.textMuted,
                ),
              ),
              Expanded(
                child: _CreditStat(
                  label: 'LÃ­mite',
                  value: 'S/ ${limit.toStringAsFixed(2)}',
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: 0, end: pct),
            builder: (context, value, child) {
              // Interpolar el color
              final animColor = Color.lerp(
                AppColors.success,
                AppColors.danger,
                value >= 0.8 ? 1.0 : (value / 0.8), // Rojo cuando >= 80%
              );

              return Semantics(
                label: 'CrÃ©dito usado: ${(value * 100).toStringAsFixed(0)}%',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      animColor ??
                          (isRisk ? AppColors.danger : AppColors.success),
                    ),
                    minHeight: 8,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(pct * 100).toStringAsFixed(0)}% usado',
              style: TextStyle(
                fontSize: 11,
                color: isRisk ? AppColors.danger : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          if (isActive) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(
                  Icons.payments_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Registrar Pago',
                  style: TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _showRegisterPayment(context),
              ),
            ),
          ],

          if (movements.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Text(
              'Movimientos recientes',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...movements.take(5).map((m) => _CreditMovementRow(movement: m)),
          ],
        ],
      ),
    );
  }
}

class _CreditMovementRow extends StatelessWidget {
  final CreditMovementEntity movement;
  const _CreditMovementRow({required this.movement});

  @override
  Widget build(BuildContext context) {
    final isCharge = movement.movementType == 'CHARGE';
    final color = isCharge ? AppColors.danger : AppColors.success;
    final icon =
        isCharge ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final prefix = isCharge ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCharge
                      ? 'Cargo'
                      : 'Pago${movement.paymentMethod != null ? ' (${movement.paymentMethod})' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (movement.notes != null && movement.notes!.isNotEmpty)
                  Text(
                    movement.notes!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$prefix S/ ${movement.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                DateFormat('d MMM', 'es').format(movement.createdAt ?? DateTime.now()),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreditStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CreditStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
