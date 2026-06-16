import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_components/order_detail_section_card.dart';

class OrderDetailPointInfo extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  const OrderDetailPointInfo({
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class OrderDetailPointsSection extends StatelessWidget {
  final int pointsUsed;
  final bool isEditing;
  final TextEditingController pointsUsedCtrl;
  final int maxPointsAvailable;
  final double pointsToSolesRatio;
  final ValueChanged<String> onPointsChanged;

  const OrderDetailPointsSection({
    super.key,
    required this.pointsUsed,
    required this.isEditing,
    required this.pointsUsedCtrl,
    required this.maxPointsAvailable,
    required this.pointsToSolesRatio,
    required this.onPointsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return OrderDetailSectionCard(
      title: 'Monedas',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OrderDetailPointInfo(
                  title: 'Monedas usadas',
                  value: pointsUsed.toString(),
                  color: Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OrderDetailPointInfo(
                  title: 'Descuento',
                  value:
                      'S/ ${(pointsUsed * pointsToSolesRatio).toStringAsFixed(2)}',
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          if (isEditing) ...[
            const SizedBox(height: 12),
            TextField(
              controller: pointsUsedCtrl,
              decoration: InputDecoration(
                labelText: 'Monedas a aplicar (Max: $maxPointsAvailable)',
                helperText:
                    'Solo se descuentan cuando la orden pase a COMPLETED.',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: onPointsChanged,
            ),
          ],
        ],
      ),
    );
  }
}
