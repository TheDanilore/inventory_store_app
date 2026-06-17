import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:inventory_store_app/models/order_model.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_components/order_detail_section_card.dart';

class OrderDetailAuditSection extends StatelessWidget {
  final OrderModel order;
  final String? updaterName;

  const OrderDetailAuditSection({
    super.key,
    required this.order,
    this.updaterName,
  });

  @override
  Widget build(BuildContext context) {
    if (order.updatedAt == null && order.createdBy == null) {
      return const SizedBox.shrink();
    }

    return OrderDetailSectionCard(
      title: 'Auditoría / Historial',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (order.createdAt != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.add_circle_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Creado el', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(order.createdAt!),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (order.updatedAt != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.edit_note_rounded, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Última modificación', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(order.updatedAt!),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      if (updaterName != null)
                        Text(
                          'por $updaterName',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
