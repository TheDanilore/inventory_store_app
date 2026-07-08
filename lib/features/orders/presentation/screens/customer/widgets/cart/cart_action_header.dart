import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/pos/presentation/providers/cart_provider.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class CartActionHeader extends StatelessWidget {
  final CartProvider cart;

  const CartActionHeader({super.key, required this.cart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: cart.isAllSelected,
                  activeColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                  onChanged: (val) {
                    cart.toggleAllSelection(val ?? false);
                  },
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Seleccionar todo',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          if (cart.selectedItems.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                cart.removeSelectedItems();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red.shade600,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: Colors.red.shade600,
              ),
              label: Text(
                'Eliminar',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Colors.red.shade600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
