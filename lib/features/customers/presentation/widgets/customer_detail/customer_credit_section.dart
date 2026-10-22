import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_credits/customer_credit_payment_sheet.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credits_cubit.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customer_detail/customer_section_card.dart';

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
    CustomerCreditPaymentSheet.show(
      context,
      onSaved: onPaymentRegistered,
      account: CustomerCreditEntity(
        id: creditId,
        profileId: customer.id,
        currentDebt: debt,
        creditLimit: limit,
        isActive: isActive,
      ),
      onSavePayment: (amount, accountId, orderId, notes, shiftId) async {
        await context.read<CustomerCreditsCubit>().registerPayment(
          amount: amount,
          accountId: accountId,
          orderId: orderId,
          notes: notes,
          shiftId: shiftId,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUnlimited = limit <= 0; // misma regla que ficha rápida y POS
    final pct = isUnlimited ? 0.0 : (debt / limit).clamp(0.0, 1.0);
    final available =
        isUnlimited ? 0.0 : (limit - debt).clamp(0.0, double.infinity);
    final isRisk = !isUnlimited && pct >= 0.8;

    return CustomerSectionCard(
      title: 'Línea de Crédito',
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
          // Fila de Estadísticas de Crédito
          Row(
            children: [
              Expanded(
                child: _CreditStat(
                  label: 'Deuda Pendiente',
                  value: 'S/ ${debt.toStringAsFixed(2)}',
                  color: debt > 0 ? AppColors.danger : AppColors.textPrimary,
                  icon: Icons.trending_up_rounded,
                ),
              ),
              const SizedBox(width: 8),
              if (isUnlimited)
                const Expanded(
                  child: _CreditStat(
                    label: 'Límite',
                    value: 'Sin límite ∞',
                    color: AppColors.teal,
                    icon: Icons.all_inclusive_rounded,
                  ),
                )
              else ...[
                Expanded(
                  child: _CreditStat(
                    label: 'Disponible',
                    value: 'S/ ${available.toStringAsFixed(2)}',
                    color: isActive ? AppColors.success : AppColors.textMuted,
                    icon: Icons.account_balance_wallet_outlined,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CreditStat(
                    label: 'Límite Total',
                    value: 'S/ ${limit.toStringAsFixed(2)}',
                    color: AppColors.textSecondary,
                    icon: Icons.speed_rounded,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          if (isUnlimited)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.tealLight.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.teal.withValues(alpha: 0.25),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_rounded, size: 16, color: AppColors.teal),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Línea de crédito abierta sin límite configurado',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.tealDark,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              tween: Tween<double>(begin: 0, end: pct),
              builder: (context, value, child) {
                final animColor = Color.lerp(
                  AppColors.success,
                  AppColors.danger,
                  value >= 0.8 ? 1.0 : (value / 0.8),
                );

                return Semantics(
                  label: 'Crédito usado: ${(value * 100).toStringAsFixed(0)}%',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: value,
                      backgroundColor: AppColors.border,
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
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isRisk
                      ? '⚠️ Nivel de riesgo crediticio alto'
                      : 'Estado regular',
                  style: TextStyle(
                    fontSize: 11,
                    color: isRisk ? AppColors.danger : AppColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${(pct * 100).toStringAsFixed(0)}% utilizado',
                  style: TextStyle(
                    fontSize: 11,
                    color: isRisk ? AppColors.danger : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],

          if (isActive) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton.icon(
                icon: Icon(
                  Icons.payments_rounded,
                  color: debt > 0 ? Colors.white : AppColors.textMuted,
                  size: 19,
                ),
                label: Text(
                  debt > 0
                      ? 'Registrar Pago de Crédito'
                      : 'Sin Deuda Pendiente',
                  style: TextStyle(
                    color: debt > 0 ? Colors.white : AppColors.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      debt > 0 ? AppColors.teal : AppColors.background,
                  foregroundColor: Colors.white,
                  elevation: debt > 0 ? 2 : 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: debt > 0 ? AppColors.teal : AppColors.border,
                    ),
                  ),
                ),
                onPressed:
                    debt > 0 ? () => _showRegisterPayment(context) : null,
              ),
            ),
          ],

          if (movements.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Movimientos recientes',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final queryParams = {
                      'name': customer.fullName,
                      'debt': debt.toString(),
                      'limit': limit.toString(),
                      'customerId': customer.id,
                    };
                    final uri = Uri(
                      path: '/customer-credit-movements/$creditId',
                      queryParameters: queryParams,
                    );
                    context.push(uri.toString());
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Row(
                    children: [
                      Text(
                        'Ver historial completo',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCharge
                      ? 'Cargo (Venta a crédito)'
                      : 'Abono / Pago${movement.paymentMethod != null ? ' (${movement.paymentMethod})' : ''}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              Text(
                DateFormat(
                  'd MMM, HH:mm',
                  'es',
                ).format(movement.createdAt ?? DateTime.now()),
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
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
  final IconData? icon;

  const _CreditStat({
    required this.label,
    required this.value,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
