import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/financial/presentation/widgets/movement_form_sheet.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';

class PosCashMovementButton extends StatefulWidget {
  final PosState posState;

  const PosCashMovementButton({super.key, required this.posState});

  static Future<void> openMovement(
    BuildContext context,
    PosState posState, {
    String? initialType,
  }) async {
    String? cashAccountId = posState.activeShift?.accountId;
    if (cashAccountId == null) {
      final cashAcc = posState.accounts.firstWhere(
        (a) => PosCalculatorUtils.accountRequiresShift(a),
        orElse:
            () =>
                posState.accounts.isNotEmpty
                    ? posState.accounts.first
                    : <String, dynamic>{},
      );
      cashAccountId = cashAcc['id'] as String?;
    }

    final saved = await MovementFormSheet.show(
      context,
      initialType: initialType ?? 'INCOME',
      preselectedAccountId: cashAccountId,
    );

    if (saved == true && context.mounted) {
      context.read<PosCubit>().initPosData(forceRefresh: true);
      if (cashAccountId != null) {
        context.read<PosCubit>().checkActiveShift(cashAccountId);
      }
      AppSnackbar.show(
        context,
        message: 'Movimiento de dinero registrado exitosamente.',
        type: SnackbarType.success,
      );
    }
  }

  @override
  State<PosCashMovementButton> createState() => _PosCashMovementButtonState();
}

class _PosCashMovementButtonState extends State<PosCashMovementButton> {
  bool _isBusy = false;

  Future<void> _handleSelected(String type) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await PosCashMovementButton.openMovement(
        context,
        widget.posState,
        initialType: type == 'ANY' ? 'INCOME' : type,
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: PopupMenuButton<String>(
        tooltip: 'Registrar movimiento de dinero (Ingreso / Egreso)',
        offset: const Offset(0, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        onSelected: _handleSelected,
        itemBuilder:
            (context) => [
              const PopupMenuItem(
                value: 'INCOME',
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_downward_rounded,
                      color: AppColors.tealDark,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Registrar Ingreso',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'EXPENSE',
                child: Row(
                  children: [
                    Icon(
                      Icons.arrow_upward_rounded,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Registrar Egreso',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'ANY',
                child: Row(
                  children: [
                    Icon(
                      Icons.swap_horiz_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Nuevo Movimiento / Transferencia',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  size: 16,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Movimiento',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
