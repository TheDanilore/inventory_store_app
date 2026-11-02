import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_confirm_dialog.dart';
import 'package:inventory_store_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';

class PosExitDialog {
  const PosExitDialog._();

  static Future<void> handleExit(
    BuildContext context, {
    required bool isCashierOnly,
  }) async {
    final authCubit = context.read<AuthCubit>();
    final cart = context.read<CartCubit>();
    final hasItems = cart.state.items.isNotEmpty;
    final posState = context.read<PosCubit>().state;
    final isShiftOpen = posState.activeShift != null;

    if (isCashierOnly) {
      final shouldLogout = await AppConfirmDialog.show(
        context,
        icon: Icons.power_settings_new_rounded,
        title: 'Cerrar Sesión de Caja',
        message:
            isShiftOpen
                ? 'Atención: Tu turno de caja aún se encuentra ABIERTO.\n\nTe recomendamos realizar el arqueo y cierre de turno en la pestaña "Turnos" antes de retirarte.\n\n¿Deseas cerrar tu sesión ahora?'
                : (hasItems
                    ? 'Tienes productos en la caja actual.\n\n¿Estás seguro de que deseas cerrar tu sesión?'
                    : '¿Estás seguro de que deseas cerrar tu sesión de cajero?'),
        confirmText: 'Cerrar Sesión',
        cancelText: 'Permanecer en Caja',
        confirmColor: AppColors.error,
      );

      if (shouldLogout == true && context.mounted) {
        await authCubit.logout();
      }
      return;
    }

    final shouldExit = await showDialog<bool>(
      context: context,
      builder:
          (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  hasItems ? Icons.warning_amber_rounded : Icons.logout_rounded,
                  color: hasItems ? AppColors.warning : AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Text('¿Salir de Caja POS?'),
              ],
            ),
            content: Text(
              hasItems
                  ? 'Tienes productos agregados en la caja. Si sales al panel administrativo, la venta actual continuará en tu carrito para cuando regreses.\n\n¿Deseas volver al panel de administración ERP?'
                  : '¿Estás seguro de que deseas salir del Punto de Venta y regresar al panel de administración ERP?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx, false),
                child: const Text('Quedarme en Caja'),
              ),
              _ExitConfirmButton(dialogCtx: dialogCtx),
            ],
          ),
    );

    if (shouldExit == true && context.mounted) {
      await Future.delayed(const Duration(milliseconds: 90));
      if (context.mounted) {
        context.go('/');
      }
    }
  }
}

class _ExitConfirmButton extends StatefulWidget {
  final BuildContext dialogCtx;
  const _ExitConfirmButton({required this.dialogCtx});

  @override
  State<_ExitConfirmButton> createState() => _ExitConfirmButtonState();
}

class _ExitConfirmButtonState extends State<_ExitConfirmButton> {
  bool _isExiting = false;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
      onPressed:
          _isExiting
              ? null
              : () async {
                setState(() => _isExiting = true);
                await Future.delayed(const Duration(milliseconds: 60));
                if (widget.dialogCtx.mounted) {
                  Navigator.pop(widget.dialogCtx, true);
                }
              },
      child:
          _isExiting
              ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
              : const Text('Salir al ERP'),
    );
  }
}
