import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/core/widgets/app_sheet_drag_handle.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/header/pos_cash_movement_button.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/header/pos_shift_action_chip.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/header/pos_warehouse_selector.dart';

class PosMobileOptionsSheet {
  static void show(BuildContext context, PosState posState) {
    final posCubit = context.read<PosCubit>();
    final cashShiftsCubit = context.read<CashShiftsCubit>();
    final cartCubit = context.read<CartCubit>();
    final authCubit = context.read<AuthCubit>();

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return MultiBlocProvider(
          providers: [
            BlocProvider.value(value: posCubit),
            BlocProvider.value(value: cashShiftsCubit),
            BlocProvider.value(value: cartCubit),
            BlocProvider.value(value: authCubit),
          ],
          child: BlocBuilder<PosCubit, PosState>(
            buildWhen:
                (prev, current) =>
                    prev.activeShift != current.activeShift ||
                    prev.warehouses != current.warehouses ||
                    prev.selectedWarehouseId != current.selectedWarehouseId ||
                    prev.isLoading != current.isLoading,
            builder: (ctx, state) {
              final activeShift = state.activeShift;
              final isShiftOpen = activeShift != null && activeShift.isOpen;
              final user = authCubit.state.currentUser;
              final fullName =
                  user?.fullName.trim().isNotEmpty == true
                      ? user!.fullName.trim()
                      : 'Usuario';
              final roleName = user?.role ?? 'cajero';
              final roleLabel = AppRoles.getLabel(roleName);
              final avatarUrl = user?.avatarUrl;
              final names =
                  fullName.split(' ').where((s) => s.isNotEmpty).toList();
              final initials =
                  names.isNotEmpty
                      ? (names.length >= 2
                          ? '${names[0][0]}${names[1][0]}'.toUpperCase()
                          : names[0][0].toUpperCase())
                      : 'U';

              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(ctx).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AppSheetDragHandle(
                      padding: EdgeInsets.only(bottom: 16),
                    ),

                    // ── Card de Identidad de Usuario ─────────────────────
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.primary.withValues(
                              alpha: 0.15,
                            ),
                            backgroundImage:
                                avatarUrl != null && avatarUrl.isNotEmpty
                                    ? NetworkImage(avatarUrl)
                                    : null,
                            child:
                                avatarUrl == null || avatarUrl.isEmpty
                                    ? Text(
                                      initials,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    )
                                    : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  roleLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ── Movimientos de Dinero (Ingreso / Egreso) ─────────
                    const Text(
                      'Movimientos de Dinero',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.tealDark,
                              backgroundColor: AppColors.teal.withValues(
                                alpha: 0.08,
                              ),
                              side: BorderSide(
                                color: AppColors.teal.withValues(alpha: 0.3),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              PosCashMovementButton.openMovement(
                                context,
                                state,
                                initialType: 'INCOME',
                              );
                            },
                            icon: const Icon(
                              Icons.arrow_downward_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Ingreso',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              backgroundColor: AppColors.danger.withValues(
                                alpha: 0.08,
                              ),
                              side: BorderSide(
                                color: AppColors.danger.withValues(alpha: 0.3),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(ctx);
                              PosCashMovementButton.openMovement(
                                context,
                                state,
                                initialType: 'EXPENSE',
                              );
                            },
                            icon: const Icon(
                              Icons.arrow_upward_rounded,
                              size: 18,
                            ),
                            label: const Text(
                              'Egreso',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    const Text(
                      'Turno de Caja',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PosShiftActionChip(
                      posState: state,
                      isShiftOpen: isShiftOpen,
                    ),
                    const SizedBox(height: 18),

                    const Text(
                      'Almacén Activo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    PosWarehouseSelector(posState: state),
                    const SizedBox(height: 20),
                    const Divider(color: AppColors.divider, height: 1),
                    const SizedBox(height: 14),

                    // ── Botón Cerrar Sesión ─────────────────────────────────
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        backgroundColor: AppColors.error.withValues(
                          alpha: 0.06,
                        ),
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.25),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final confirmed = await AppConfirmDialog.show(
                          context,
                          title: 'Cerrar Sesión',
                          message:
                              '¿Estás seguro de que deseas salir del sistema?',
                          confirmText: 'Cerrar Sesión',
                          icon: Icons.logout_rounded,
                        );
                        if (confirmed == true && context.mounted) {
                          await context.read<AuthCubit>().logout();
                        }
                      },
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text(
                        'Cerrar Sesión',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
