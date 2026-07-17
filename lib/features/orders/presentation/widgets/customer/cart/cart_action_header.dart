import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class CartActionHeader extends StatelessWidget {
  final CartCubit cartCubit;
  final CartState cartState;

  const CartActionHeader({super.key, required this.cartCubit, required this.cartState});

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
                  value: cartState.isAllSelected,
                  activeColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                  onChanged: (val) {
                    cartCubit.toggleAllSelection(val ?? false);
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
          if (cartState.selectedItems.isNotEmpty)
            TextButton.icon(
              onPressed: () {
                cartCubit.removeSelected();
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
