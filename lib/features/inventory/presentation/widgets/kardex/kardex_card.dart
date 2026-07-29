import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/kardex_movement_entity.dart';

class KardexCard extends StatelessWidget {
  final KardexMovementEntity item;
  final bool isLast;

  const KardexCard({super.key, required this.item, this.isLast = false});

  Widget _buildBadge(String type) {
    final upperType = type.toUpperCase();
    final isEntry = upperType.contains('INGRESO');
    final isReturn = upperType.contains('DEVOLUCIÓN');
    final isSale = upperType.contains('VENTA');

    Color bgColor = Colors.red.shade50;
    Color textColor = Colors.red.shade700;
    String label = 'SALIDA';

    if (isEntry) {
      bgColor = Colors.green.shade50;
      textColor = Colors.green.shade700;
      label = 'INGRESO';
    } else if (isReturn) {
      bgColor = Colors.purple.shade50;
      textColor = Colors.purple.shade700;
      label = 'DEVOLUCIÓN';
    } else if (isSale) {
      bgColor = Colors.blue.shade50;
      textColor = Colors.blue.shade700;
      label = 'VENTA';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final iconColor =
        item.type.toUpperCase().contains('INGRESO') ||
                item.type.toUpperCase().contains('DEVOLUCIÓN')
            ? (item.type.toUpperCase().contains('DEVOLUCIÓN')
                ? Colors.purple
                : Colors.green)
            : (item.type.toUpperCase().contains('VENTA')
                ? Colors.blue
                : Colors.red);
    final iconData =
        item.type.toUpperCase().contains('INGRESO') ||
                item.type.toUpperCase().contains('DEVOLUCIÓN')
            ? Icons.arrow_downward
            : Icons.arrow_upward;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                if (!isLast)
                  Positioned(
                    top: 24,
                    bottom: 0,
                    child: Container(width: 2, color: Colors.grey.shade300),
                  ),
                Positioned(
                  top: 24,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: iconColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(item.date),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        _buildBadge(item.type),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Icon(iconData, color: iconColor),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.description,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.reference,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _Metric(
                          label: 'Cantidad',
                          value: item.quantity.toStringAsFixed(2),
                        ),
                        _Metric(
                          label: 'Costo Unit.',
                          value: 'S/ ${item.unitCost.toStringAsFixed(2)}',
                        ),
                        _Metric(
                          label: 'Stock',
                          value: item.balance.toStringAsFixed(2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year  $hour:$minute';
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}
