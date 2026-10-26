import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

/// Barra de acciones operativas (Ingresar / Salida de Stock) dentro del cuerpo del quick view.
class QuickViewStockActionButtons extends StatelessWidget {
  final VoidCallback onStockEntry;
  final VoidCallback onStockExit;

  const QuickViewStockActionButtons({
    super.key,
    required this.onStockEntry,
    required this.onStockExit,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onStockEntry,
            icon: const Icon(Icons.add_box_rounded, size: 16),
            label: const Text(
              'Ingresar Stock',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onStockExit,
            icon: const Icon(Icons.outbox_rounded, size: 16),
            label: const Text(
              'Registrar Salida',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Barra fija inferior con accesos directos a Kárdex, Edición del producto y Ficha Completa.
class QuickViewFooterActions extends StatelessWidget {
  final VoidCallback onOpenKardex;
  final VoidCallback onEditProduct;
  final VoidCallback onOpenFullView;

  const QuickViewFooterActions({
    super.key,
    required this.onOpenKardex,
    required this.onEditProduct,
    required this.onOpenFullView,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Kárdex
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onOpenKardex,
            icon: const Icon(Icons.receipt_long_rounded, size: 16),
            label: const Text(
              'Kárdex',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Editar Producto
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onEditProduct,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text(
              'Editar',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Ver Ficha Completa
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: onOpenFullView,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text(
              'Ficha Completa',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
