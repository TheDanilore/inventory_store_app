import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/common/customer_avatar_large.dart';

/// Modal Inferior Táctil (Apple HIG Style) para interacción rápida con el cliente
class MobileCustomerActionSheet extends StatelessWidget {
  final CustomerEntity customer;
  final VoidCallback onOpenDetail;
  final VoidCallback onEdit;
  final VoidCallback onWhatsApp;
  final VoidCallback onCall;
  final VoidCallback onCopyDoc;

  const MobileCustomerActionSheet({
    super.key,
    required this.customer,
    required this.onOpenDetail,
    required this.onEdit,
    required this.onWhatsApp,
    required this.onCall,
    required this.onCopyDoc,
  });

  @override
  Widget build(BuildContext context) {
    final c = customer;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              CustomerAvatarLarge(customer: c),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.fullName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${c.documentType ?? 'DOC'}: ${c.documentNumber ?? 'Sin documento'}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),

          // Acciones con target táctil mínimo de 48dp
          ListTile(
            leading: const Icon(
              Icons.visibility_outlined,
              color: AppColors.primary,
            ),
            title: const Text('Ver ficha y pedidos completos'),
            onTap: onOpenDetail,
          ),
          if (c.phone != null && c.phone!.isNotEmpty) ...[
            ListTile(
              leading: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Color(0xFF25D366),
              ),
              title: const Text('Enviar mensaje de WhatsApp'),
              subtitle: Text(c.phone!),
              onTap: onWhatsApp,
            ),
            ListTile(
              leading: const Icon(
                Icons.phone_outlined,
                color: AppColors.textPrimary,
              ),
              title: const Text('Llamar por teléfono'),
              onTap: onCall,
            ),
          ],
          if (c.documentNumber != null && c.documentNumber!.isNotEmpty)
            ListTile(
              leading: const Icon(
                Icons.copy_rounded,
                color: AppColors.textSecondary,
              ),
              title: const Text('Copiar número de documento'),
              onTap: onCopyDoc,
            ),
          ListTile(
            leading: const Icon(
              Icons.edit_outlined,
              color: AppColors.textSecondary,
            ),
            title: const Text('Editar información'),
            onTap: onEdit,
          ),
        ],
      ),
    );
  }
}
