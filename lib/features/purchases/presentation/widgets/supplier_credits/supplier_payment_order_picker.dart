import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';

class SupplierPaymentOrderPicker extends StatelessWidget {
  final bool loadingOrders;
  final String? errorMessage;
  final List<PendingPurchaseOrderEntity> pendingOrders;
  final String? selectedOrderId;
  final ValueChanged<String?> onSelectOrder;
  final VoidCallback onRetry;

  const SupplierPaymentOrderPicker({
    super.key,
    required this.loadingOrders,
    this.errorMessage,
    required this.pendingOrders,
    required this.selectedOrderId,
    required this.onSelectOrder,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingOrders) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 16,
              color: AppColors.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                errorMessage!,
                style: const TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OrderSelectionTile(
          label: 'Distribuir automáticamente',
          sublabel: 'FIFO — salda los pedidos más antiguos primero',
          isSelected: selectedOrderId == null,
          onTap: () => onSelectOrder(null),
        ),
        ...pendingOrders.map((order) {
          final pending = order.pendingAmount;
          return OrderSelectionTile(
            label: 'Pedido #${order.shortId}',
            sublabel:
                order.isPartial
                    ? 'Pago parcial · Pendiente S/ ${pending.toStringAsFixed(2)}'
                    : 'Sin pagar · S/ ${pending.toStringAsFixed(2)}',
            isSelected: selectedOrderId == order.id,
            onTap: () => onSelectOrder(order.id),
          );
        }),
        if (pendingOrders.isEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppColors.textMuted,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No se encontraron pedidos pendientes. El pago se aplicará a la deuda general.',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class OrderSelectionTile extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool isSelected;
  final VoidCallback onTap;

  const OrderSelectionTile({
    super.key,
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.tealLight : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.teal : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppColors.teal : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color:
                          isSelected
                              ? AppColors.tealDark
                              : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? AppColors.teal : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
