import 'package:flutter/material.dart';
import 'package:inventory_store_app/providers/cart_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';

class CartActionHeader extends StatelessWidget {
  final CartProvider cart;

  const CartActionHeader({super.key, required this.cart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Checkbox(
                value: cart.isAllSelected,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  cart.toggleAllSelection(val ?? false);
                },
              ),
              const SizedBox(width: 8),
              const Text(
                'Seleccionar Todos',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (cart.selectedItems.isNotEmpty)
            TextButton(
              onPressed: () {
                cart.removeSelectedItems();
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Eliminar seleccionados'),
            ),
        ],
      ),
    );
  }
}
