import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

/// Menú contextual emergente (clic derecho / pulsación larga) para clientes.
class CustomersContextMenu {
  const CustomersContextMenu._();

  static void show({
    required BuildContext context,
    required Offset position,
    required CustomerEntity customer,
    required VoidCallback onInspector,
    required VoidCallback onDetail,
    required VoidCallback onEdit,
    required void Function(String phone) onWhatsApp,
    required void Function(String phone) onCopyPhone,
    required void Function(String doc, String docType) onCopyDoc,
  }) {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 8,
      items: [
        const PopupMenuItem(
          value: 'inspector',
          child: Row(
            children: [
              Icon(
                Icons.view_sidebar_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 10),
              Text('Vista rápida (Inspector)', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'detail',
          child: Row(
            children: [
              Icon(
                Icons.visibility_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              SizedBox(width: 10),
              Text('Ver ficha completa', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: AppColors.slate),
              SizedBox(width: 10),
              Text('Editar datos', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        if (customer.phone != null && customer.phone!.isNotEmpty) ...[
          const PopupMenuItem(
            value: 'whatsapp',
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 18,
                  color: Color(0xFF25D366),
                ),
                SizedBox(width: 10),
                Text('Enviar WhatsApp', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'copy_phone',
            child: Row(
              children: [
                Icon(Icons.copy_rounded, size: 18, color: AppColors.slate),
                SizedBox(width: 10),
                Text('Copiar teléfono', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
        if (customer.documentNumber != null &&
            customer.documentNumber!.isNotEmpty)
          const PopupMenuItem(
            value: 'copy_doc',
            child: Row(
              children: [
                Icon(Icons.badge_outlined, size: 18, color: AppColors.slate),
                SizedBox(width: 10),
                Text('Copiar documento', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'inspector':
          onInspector();
          break;
        case 'detail':
          onDetail();
          break;
        case 'edit':
          onEdit();
          break;
        case 'whatsapp':
          if (customer.phone != null) onWhatsApp(customer.phone!);
          break;
        case 'copy_phone':
          if (customer.phone != null) onCopyPhone(customer.phone!);
          break;
        case 'copy_doc':
          if (customer.documentNumber != null) {
            onCopyDoc(
              customer.documentNumber!,
              customer.documentType ?? 'Documento',
            );
          }
          break;
      }
    });
  }
}
