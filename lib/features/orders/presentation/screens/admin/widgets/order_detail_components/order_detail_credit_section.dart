import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/admin/widgets/order_detail_components/order_detail_section_card.dart';

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
      return OrderDetailSectionCard(
        title: 'Crédito',
        child: Text(
          'Sin cliente asignado para mostrar crédito.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      );
    }

    if (creditInfo == null) {
      return OrderDetailSectionCard(
        title: 'Crédito',
        child: Text(
          'Este cliente no tiene línea de crédito registrada.',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
        ),
      );
    }

    final isActive = creditInfo!['is_active'] == true;
    final limit = (creditInfo!['credit_limit'] as num).toDouble();
    final debt = (creditInfo!['current_debt'] as num).toDouble();
    final available = (limit - debt).clamp(0.0, double.infinity);

    return OrderDetailSectionCard(
      title: 'Resumen de Línea de Crédito',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isActive ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color:
                        isActive ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                ),
                child: Text(
                  isActive ? 'Crédito activo' : 'Crédito inactivo',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color:
                        isActive ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CreditStatCell(
                  label: 'Límite Global',
                  value: 'S/ ${limit.toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: _CreditStatCell(
                  label: 'Deuda Total',
                  value: 'S/ ${debt.toStringAsFixed(2)}',
                  valueColor: debt > 0 ? Colors.deepOrange : Colors.teal,
                  bold: debt > 0,
                ),
              ),
              Expanded(
                child: _CreditStatCell(
                  label: 'Disponible',
                  value: 'S/ ${available.toStringAsFixed(2)}',
                  valueColor: available > 0 ? Colors.teal : Colors.grey,
                ),
              ),
            ],
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

  const _CreditStatCell({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
