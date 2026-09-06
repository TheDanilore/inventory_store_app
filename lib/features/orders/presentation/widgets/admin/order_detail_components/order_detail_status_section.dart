import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_section_card.dart';

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
      options = ['COMPLETED', 'RETURNED'];
    } else {
      options = [originalStatus.toUpperCase()];
    }

    if (!isEditing) {
      Color badgeColor;
      String label;
      IconData icon;
      String subtitle;
      switch (currentStatus.toUpperCase()) {
        case 'COMPLETED':
          badgeColor = AppColors.teal;
          label = 'COMPLETADO';
          icon = Icons.check_circle_rounded;
          subtitle = 'Pedido completado y procesado en inventario';
          break;
        case 'PENDING':
          badgeColor = AppColors.amberDark;
          label = 'BORRADOR';
          icon = Icons.edit_note_rounded;
          subtitle = 'Borrador editable antes de confirmar cobro';
          break;
        case 'CANCELLED':
          badgeColor = AppColors.error;
          label = 'CANCELADO';
          icon = Icons.cancel_rounded;
          subtitle = 'Pedido cancelado sin efecto en inventario';
          break;
        case 'RETURNED':
          badgeColor = Colors.purple.shade700;
          label = 'DEVUELTO';
          icon = Icons.rotate_left_rounded;
          subtitle = 'Venta reembolsada o devuelta';
          break;
        default:
          badgeColor = AppColors.slate;
          label = currentStatus;
          icon = Icons.info_outline_rounded;
          subtitle = 'Estado actual del pedido';
      }

      return OrderDetailSectionCard(
        title: 'Estado del Pedido',
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: badgeColor.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: badgeColor),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 16, color: badgeColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
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
              } else if (s == 'RETURNED') {
                label = '🔄  DEVOLVER PEDIDO (REEMBOLSO)';
                itemColor = Colors.purple.shade700;
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
