import 'package:flutter/material.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/screens/admin/widgets/order_detail_components/order_detail_section_card.dart';

class OrderDetailStatusSection extends StatelessWidget {
  final String currentStatus;
  final String originalStatus;
  final bool isEditing;
  final ValueChanged<String?> onChanged;

  const OrderDetailStatusSection({
    super.key,
    required this.currentStatus,
    required this.originalStatus,
    required this.isEditing,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    List<String> options = [];
    if (originalStatus.toUpperCase() == 'PENDING') {
      options = ['PENDING', 'COMPLETED', 'CANCELLED'];
    } else if (originalStatus.toUpperCase() == 'COMPLETED') {
      options = ['COMPLETED', 'CANCELLED'];
    } else {
      options = [originalStatus.toUpperCase()];
    }

    if (!isEditing) {
      Color badgeColor;
      String label;
      switch (currentStatus.toUpperCase()) {
        case 'COMPLETED':
          badgeColor = Colors.teal;
          label = 'COMPLETADO';
          break;
        case 'PENDING':
          badgeColor = Colors.orange.shade700;
          label = 'PENDIENTE (Borrador)';
          break;
        case 'CANCELLED':
          badgeColor = Colors.red;
          label = 'CANCELADO';
          break;
        default:
          badgeColor = Colors.grey;
          label = currentStatus;
      }

      return OrderDetailSectionCard(
        title: 'Estado del Pedido',
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return OrderDetailSectionCard(
      title: 'Estado del Pedido',
      child: DropdownButtonFormField<String>(
        initialValue:
            options.contains(currentStatus.toUpperCase())
                ? currentStatus.toUpperCase()
                : options.first,
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          fillColor: Colors.grey.shade50,
          filled: true,
        ),
        icon: const Icon(
          Icons.arrow_drop_down_circle_rounded,
          color: AppColors.primary,
        ),
        items:
            options.map((s) {
              String label = s;
              Color itemColor = Colors.black87;

              if (s == 'COMPLETED') {
                label = '✅  COMPLETAR PEDIDO';
                itemColor = Colors.teal.shade700;
              } else if (s == 'PENDING') {
                label = '⏳  MANTENER PENDIENTE';
                itemColor = Colors.orange.shade800;
              } else if (s == 'CANCELLED') {
                label = '❌  CANCELAR PEDIDO';
                itemColor = Colors.red.shade700;
              }

              return DropdownMenuItem(
                value: s,
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: itemColor,
                  ),
                ),
              );
            }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
