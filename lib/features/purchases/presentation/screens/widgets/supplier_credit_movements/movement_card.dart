import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/features/purchases/data/models/supplier_credit_movement_model.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class SupplierCreditMovementCard extends StatelessWidget {
  final SupplierCreditMovementModel movement;

  const SupplierCreditMovementCard({super.key, required this.movement});

  @override
  Widget build(BuildContext context) {
    // Si es CHARGE (nos fiaron), la deuda aumenta (Naranja). Si es PAYMENT (amortizamos), la deuda baja (Verde).
    final isCharge = movement.isCharge;
    final color = isCharge ? Colors.orange : Colors.green;
    final bgColor = isCharge ? Colors.orange.shade50 : Colors.green.shade50;
    final icon =
        isCharge ? Icons.local_shipping_rounded : Icons.payments_rounded;
    final sign = isCharge ? '+' : '-';
    final timeStr =
        movement.createdAt != null
            ? DateFormat('HH:mm').format(movement.createdAt!.toLocal())
            : '--:--';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCharge ? 'Compra a crédito' : 'Amortización enviada',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isCharge && movement.orderTotalAmount != null)
                    Text(
                      'Total de orden: S/ ${movement.orderTotalAmount!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  if (movement.purchaseOrderId != null)
                    Text(
                      'Orden #${movement.purchaseOrderId!.substring(0, 8)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  if (!isCharge && movement.paymentMethod != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _MethodChip(method: movement.paymentMethod!),
                    ),
                  if (movement.notes?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        movement.notes!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          movement.createdByName ?? 'Sistema',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '$sign S/ ${movement.amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MethodChip extends StatelessWidget {
  final String method;
  const _MethodChip({required this.method});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Text(
        method,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.green.shade700,
        ),
      ),
    );
  }
}
