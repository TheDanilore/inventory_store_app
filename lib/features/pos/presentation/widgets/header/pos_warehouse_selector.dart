import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/core/widgets/permission_guard.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';

class PosWarehouseSelector extends StatelessWidget {
  final PosState posState;

  const PosWarehouseSelector({super.key, required this.posState});

  @override
  Widget build(BuildContext context) {
    if (posState.isLoading && posState.warehouses.isEmpty) {
      return Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Cargando almacén...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (posState.warehouses.isEmpty) {
      return Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: AppColors.error,
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: const Text(
                'Sin almacenes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
              onPressed:
                  () =>
                      context.read<PosCubit>().initPosData(forceRefresh: true),
              child: const Text('Reintentar', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    final canViewAll = context.hasPermission(AppPermissions.warehousesViewAll);
    final currentWh = posState.warehouses.firstWhere(
      (w) => w.id == posState.selectedWarehouseId,
      orElse: () => posState.warehouses.first,
    );

    // Si el usuario no cuenta con el permiso warehouses.view_all o solo hay un almacén:
    if (!canViewAll || posState.warehouses.length == 1) {
      return Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.store_mall_directory_rounded,
              size: 17,
              color: AppColors.primary,
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                currentWh.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (!canViewAll) ...[
              const SizedBox(width: 6),
              Tooltip(
                message: 'Almacén asignado exclusivamente a tu usuario.',
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Usuario con permiso warehouses.view_all: Dropdown interactivo
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: MediaQuery.of(context).size.width < 800,
          value:
              posState.selectedWarehouseId ??
              (posState.warehouses.isNotEmpty
                  ? posState.warehouses.first.id
                  : null),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.textSecondary,
          ),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          items:
              posState.warehouses.map((wh) {
                return DropdownMenuItem<String>(
                  value: wh.id,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.warehouse_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(wh.name),
                    ],
                  ),
                );
              }).toList(),
          onChanged: (newWhId) {
            if (newWhId != null && newWhId != posState.selectedWarehouseId) {
              context.read<PosCubit>().setWarehouse(newWhId);

              final cart = context.read<CartCubit>();
              if (cart.state.items.isNotEmpty) {
                cart.clearCart();
                AppSnackbar.show(
                  context,
                  message:
                      'Almacén cambiado. El carrito se vació para sincronizar stocks.',
                  type: SnackbarType.warning,
                );
              } else {
                AppSnackbar.show(
                  context,
                  message: 'Almacén activo cambiado correctamente',
                  type: SnackbarType.info,
                );
              }
            }
          },
        ),
      ),
    );
  }
}
