import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:inventory_store_app/features/catalog/presentation/bloc/admin_catalog/admin_catalog_cubit.dart';

class PosCheckoutFab extends StatefulWidget {
  const PosCheckoutFab({super.key});

  @override
  State<PosCheckoutFab> createState() => _PosCheckoutFabState();
}

class _PosCheckoutFabState extends State<PosCheckoutFab> {
  bool _isNavigatingToCheckout = false;

  Future<void> _handleCheckout(BuildContext context) async {
    if (_isNavigatingToCheckout) return;
    _isNavigatingToCheckout = true;
    try {
      final sold = await context.push<Map<String, int>>('/pos-checkout');
      if (sold != null && context.mounted) {
        context.read<AdminCatalogCubit>().decrementStockLocal(sold);
      }
    } finally {
      if (mounted) {
        _isNavigatingToCheckout = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CartCubit, CartState, (bool, int, double)>(
      selector: (state) {
        final hasItems = state.items.isNotEmpty;
        final itemCount = state.items.values.fold<int>(
          0,
          (sum, item) => sum + item.quantity,
        );
        return (hasItems, itemCount, state.totalAmount);
      },
      builder: (context, data) {
        final (hasItems, itemCount, totalAmount) = data;

        return FloatingActionButton.extended(
          onPressed: () => _handleCheckout(context),
          backgroundColor: hasItems ? AppColors.primary : AppColors.textPrimary,
          foregroundColor: Colors.white,
          icon: Icon(
            hasItems
                ? Icons.shopping_bag_rounded
                : Icons.shopping_cart_checkout_rounded,
            size: 20,
          ),
          label: Text(
            hasItems
                ? 'Ir a Caja ($itemCount) • S/ ${totalAmount.toStringAsFixed(2)}'
                : 'Ir a Caja',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        );
      },
    );
  }
}
