import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_exits/exit_quantity_stepper.dart';

class ExitFormSummaryBar extends StatelessWidget {
  final VoidCallback onSave;

  const ExitFormSummaryBar({super.key, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: BlocSelector<
        InventoryExitFormCubit,
        InventoryExitFormState,
        ({int count, double totalLoss, double totalUnits, bool isSaving})
      >(
        selector: (state) {
          final items = state.items;
          return (
            count: items.length,
            totalLoss: items.fold<double>(0.0, (s, i) => s + i.totalCost),
            totalUnits: items.fold<double>(0.0, (s, i) => s + i.quantity),
            isSaving: state.isSaving,
          );
        },
        builder: (context, data) {
          final hasItems = data.count > 0;
          final isSaving = data.isSaving;

          return Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Pérdida estimada',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'S/ ${data.totalLoss.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                              color:
                                  hasItems
                                      ? AppColors.danger
                                      : AppColors.textMuted,
                            ),
                          ),
                        ),
                        if (hasItems)
                          Text(
                            '${data.count} ${data.count == 1 ? 'línea' : 'líneas'} · ${formatExitQty(data.totalUnits)} ${data.totalUnits == 1 ? 'unidad' : 'unidades'}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: (!hasItems || isSaving) ? null : onSave,
                    icon:
                        isSaving
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.textMuted,
                              ),
                            )
                            : const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 20,
                            ),
                    label: Text(isSaving ? 'Guardando...' : 'Confirmar salida'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.border,
                      disabledForegroundColor: AppColors.textMuted,
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
