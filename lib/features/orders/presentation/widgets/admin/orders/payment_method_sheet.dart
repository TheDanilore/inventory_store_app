import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class PaymentMethodSheet extends StatelessWidget {
  final OrderEntity order;

  const PaymentMethodSheet({super.key, required this.order});

  static Future<String?> show(BuildContext context, OrderEntity order) {
    final isWide = MediaQuery.of(context).size.width >= 800;

    if (isWide) {
      return showDialog<String>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              content: SizedBox(
                width: 400,
                child: PaymentMethodSheet(order: order),
              ),
            ),
      );
    }

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: PaymentMethodSheet(order: order),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Selecciona cómo pagó el cliente:',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Monto a cobrar: S/ ${order.totalAmount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 24),
        _PaymentOptionButton(
          label: 'EFECTIVO',
          icon: Icons.payments_outlined,
          onSelect: () => Navigator.pop(context, 'EFECTIVO'),
        ),
        const SizedBox(height: 12),
        _PaymentOptionButton(
          label: 'YAPE',
          icon: Icons.phone_android_rounded,
          onSelect: () => Navigator.pop(context, 'YAPE'),
        ),
        const SizedBox(height: 12),
        _PaymentOptionButton(
          label: 'PLIN',
          icon: Icons.phone_android_rounded,
          onSelect: () => Navigator.pop(context, 'PLIN'),
        ),
        const SizedBox(height: 12),
        _PaymentOptionButton(
          label: 'TARJETA',
          icon: Icons.credit_card_rounded,
          onSelect: () => Navigator.pop(context, 'TARJETA'),
        ),
        const SizedBox(height: 12),
        _PaymentOptionButton(
          label: 'CRÉDITO',
          icon: Icons.schedule_rounded,
          onSelect: () => Navigator.pop(context, 'CRÉDITO'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _PaymentOptionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onSelect;

  const _PaymentOptionButton({
    required this.label,
    required this.icon,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
