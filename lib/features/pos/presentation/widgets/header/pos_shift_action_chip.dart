import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/open_shift_sheet.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/close_shift_sheet.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';

class PosShiftActionChip extends StatefulWidget {
  final PosState posState;
  final bool isShiftOpen;

  const PosShiftActionChip({
    super.key,
    required this.posState,
    required this.isShiftOpen,
  });

  @override
  State<PosShiftActionChip> createState() => _PosShiftActionChipState();
}

class _PosShiftActionChipState extends State<PosShiftActionChip> {
  bool _isActionBusy = false;

  Future<void> _handleShiftAction() async {
    if (_isActionBusy) return;
    setState(() => _isActionBusy = true);

    try {
      if (widget.isShiftOpen) {
        final activeShift = widget.posState.activeShift;
        if (activeShift == null) return;

        final shiftsCubit = context.read<CashShiftsCubit>();
        final expected = await shiftsCubit.calcExpected(
          activeShift.id,
          activeShift.accountId ?? '',
          activeShift.openingAmount,
        );
        if (!mounted) return;

        final closed = await CloseShiftSheet.show(
          context,
          shift: activeShift,
          expectedAmount: expected,
        );
        if (closed == true && mounted) {
          context.read<PosCubit>().clearActiveShift();
          await context.read<PosCubit>().refreshAccountsAndShift();
          if (mounted) {
            context.read<CashShiftsCubit>().fetchShifts();
          }
        }
      } else {
        final cashAccounts =
            widget.posState.accounts
                .where((a) => PosCalculatorUtils.accountRequiresShift(a))
                .toList();
        final opened = await OpenShiftSheet.show(
          context,
          accounts: cashAccounts,
        );
        if (opened == true && mounted) {
          await context.read<PosCubit>().refreshAccountsAndShift();
          if (mounted) {
            context.read<CashShiftsCubit>().fetchShifts();
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isActionBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final posState = widget.posState;
    final isShiftOpen = widget.isShiftOpen;

    if (posState.isLoading &&
        posState.activeShift == null &&
        posState.accounts.isEmpty) {
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
          mainAxisAlignment: MainAxisAlignment.center,
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
              'Verificando turno...',
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

    final activeShift = posState.activeShift;
    final rawName = activeShift?.openedByName?.trim() ?? '';
    final tooltipMsg =
        isShiftOpen
            ? 'Cajero: ${rawName.isNotEmpty ? rawName : "Cajero en turno"} • Apertura: S/ ${activeShift?.openingAmount.toStringAsFixed(2) ?? "0.00"}\n(Clic para cerrar turno)'
            : 'La caja física está cerrada. Clic para abrir turno.';

    return Tooltip(
      message: tooltipMsg,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: _handleShiftAction,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color:
                isShiftOpen
                    ? AppColors.success.withValues(alpha: 0.1)
                    : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  isShiftOpen
                      ? AppColors.success.withValues(alpha: 0.4)
                      : const Color(0xFFF59E0B).withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isShiftOpen) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ] else ...[
                const Icon(
                  Icons.lock_clock_rounded,
                  size: 16,
                  color: Color(0xFFB45309),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                isShiftOpen
                    ? (() {
                      final rawName = activeShift?.openedByName?.trim() ?? '';
                      final firstName =
                          rawName.isNotEmpty ? rawName.split(' ').first : '';
                      return firstName.isNotEmpty
                          ? 'Turno Abierto ($firstName)'
                          : 'Turno Abierto • S/ ${activeShift!.openingAmount.toStringAsFixed(2)}';
                    })()
                    : 'Caja Física Cerrada • Abrir Turno',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color:
                      isShiftOpen
                          ? const Color(0xFF065F46)
                          : const Color(0xFF92400E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
