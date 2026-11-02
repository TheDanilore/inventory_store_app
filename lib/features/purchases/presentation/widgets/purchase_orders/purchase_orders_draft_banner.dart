import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Banner de alerta interactivo que notifica la presencia de un borrador local de compra.
class PurchaseOrdersDraftBanner extends StatelessWidget {
  const PurchaseOrdersDraftBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_document, color: AppColors.warning, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Tienes un borrador de compra en progreso.',
              style: TextStyle(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          FilledButton.tonal(
            onPressed: () {
              context.go('/purchase-orders/form');
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              visualDensity: VisualDensity.compact,
              backgroundColor: AppColors.warning.withValues(alpha: 0.2),
              foregroundColor: AppColors.warning,
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}
