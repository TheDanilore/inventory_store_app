import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/credit_movement_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class MovementCard extends StatelessWidget {
  final CreditMovementModel movement;

  const MovementCard({super.key, required this.movement});

  @override
  Widget build(BuildContext context) {
    final isCharge = movement.isCharge;
    final color = isCharge ? Colors.orange : Colors.green;
    final bgColor = isCharge ? Colors.orange.shade50 : Colors.green.shade50;
    final icon =
        isCharge ? Icons.shopping_cart_rounded : Icons.payments_rounded;
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
            // Ícono
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),

            // Info central
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isCharge ? 'Cargo por venta' : 'Pago registrado',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 4),

                  if (isCharge && movement.orderTotalAmount != null)
                    Text(
                      'Venta: S/ ${movement.orderTotalAmount!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),

                  if (movement.orderNumber != null)
                    Text(
                      'Pedido #${movement.orderNumber!.substring(0, 8)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),

                  if (!isCharge && movement.orderPaymentMethod != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _MethodChip(method: movement.orderPaymentMethod!),
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
                        color: AppColors.textHint,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          movement.createdByName ?? 'Desconocido',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textHint,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Monto y hora
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$sign S/ ${movement.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
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
    Color chipColor;
    if (method.toUpperCase() == 'YAPE' || method.toUpperCase() == 'PLIN') {
      chipColor = Colors.purple;
    } else if (method.toUpperCase().contains('TARJETA')) {
      chipColor = Colors.blue;
    } else if (method.toUpperCase().contains('EFECTIVO')) {
      chipColor = Colors.green;
    } else {
      chipColor = Colors.grey.shade600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: chipColor.withValues(alpha: 0.2)),
      ),
      child: Text(
        method,
        style: TextStyle(
          fontSize: 10,
          color: chipColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
