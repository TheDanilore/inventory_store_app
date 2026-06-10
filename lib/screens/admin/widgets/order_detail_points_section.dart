import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_sheet.dart';

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
  final int pointsEarned;
  final bool isEditing;
  final TextEditingController pointsUsedController;
  final ValueChanged<String> onPointsUsedChanged;

  const OrderDetailPointsSection({
    super.key,
    required this.pointsUsed,
    required this.pointsEarned,
    required this.isEditing,
    required this.pointsUsedController,
    required this.onPointsUsedChanged,
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
                  title: 'Monedas ganadas',
                  value: pointsEarned.toString(),
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          if (isEditing) ...[
            const SizedBox(height: 12),
            TextField(
              controller: pointsUsedController,
              decoration: const InputDecoration(
                labelText: 'Monedas a aplicar al completar',
                helperText:
                    'Solo se descuentan cuando la orden pase a COMPLETED.',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: onPointsUsedChanged,
            ),
          ],
        ],
      ),
    );
  }
}
