import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class OrderConfirmDialog extends StatelessWidget {
  final OrderEntity order;
  final String newStatus;

  const OrderConfirmDialog({
    super.key,
    required this.order,
    required this.newStatus,
  });

  static Future<bool?> show(
    BuildContext context, {
    required OrderEntity order,
    required String newStatus,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => OrderConfirmDialog(order: order, newStatus: newStatus),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompleting = newStatus == 'COMPLETED';
    final isCancelling = newStatus == 'CANCELLED';
    final isReturning = newStatus == 'RETURNED';
    final isCredit = order.paymentMethod == 'CRÉDITO';
    final pendingPoints = order.pointsEarned;
    final config = context.read<AppConfigCubit>();
    final isLoyaltyEnabled = config.loyaltyGlobalEnabled;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  isCompleting
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCompleting
                  ? Icons.check_circle_outline_rounded
                  : Icons.cancel_outlined,
              color: isCompleting ? Colors.green.shade700 : Colors.red.shade700,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isCompleting
                  ? 'Confirmar cobro'
                  : (isReturning ? 'Devolver pedido' : 'Cancelar pedido'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cliente: ${order.customerName}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                isCompleting ? 'Monto a cobrar: ' : 'Total del pedido: ',
                style: const TextStyle(color: Colors.grey),
              ),
              Text(
                'S/ ${order.totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: isCompleting ? AppColors.primary : Colors.red.shade700,
                ),
              ),
            ],
          ),
          if (isLoyaltyEnabled &&
              isCompleting &&
              !isCredit &&
              pendingPoints > 0) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎁', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    'El cliente ganará $pendingPoints monedas',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isCompleting && isCredit) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Se registrará como deuda de crédito.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (isCancelling || isReturning) ...[
            const SizedBox(height: 10),
            Text(
              isReturning
                  ? 'Se reintegrará el stock y se reembolsará el pago. Esta acción no se puede deshacer.'
                  : 'Esta acción no se puede deshacer. El stock NO se reintegrará automáticamente si ya fue descontado.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isCompleting ? Colors.green.shade600 : Colors.red.shade600,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            isCompleting
                ? 'Confirmar cobro'
                : (isReturning ? 'Sí, devolver' : 'Sí, cancelar'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
