import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_exit_form/inventory_exit_form_state.dart';

class ExitFormHeaderSection extends StatelessWidget {
  static const Map<String, IconData> reasons = {
    'AJUSTE': Icons.tune_rounded,
    'MERMA': Icons.trending_down_rounded,
    'DAÑO': Icons.broken_image_outlined,
    'VENCIMIENTO': Icons.event_busy_rounded,
    'ROBO/PÉRDIDA': Icons.report_problem_outlined,
    'CONSUMO INTERNO': Icons.home_work_outlined,
  };

  const ExitFormHeaderSection({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;

    return BlocSelector<
      InventoryExitFormCubit,
      InventoryExitFormState,
      ({
        String? selectedWarehouseId,
        String selectedReason,
        List<WarehouseModel> warehouses,
      })
    >(
      selector:
          (state) => (
            selectedWarehouseId: state.selectedWarehouseId,
            selectedReason: state.selectedReason,
            warehouses: state.warehouses,
          ),
      builder: (context, data) {
        final cubit = context.read<InventoryExitFormCubit>();
        final validWarehouseId =
            data.warehouses.any((w) => w.id == data.selectedWarehouseId)
                ? data.selectedWarehouseId
                : null;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 16 : 24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.storefront_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Datos principales',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'wh_${validWarehouseId}_${data.warehouses.length}',
                ),
                initialValue: validWarehouseId,
                isExpanded: true,
                icon: const Icon(Icons.expand_more_rounded),
                decoration: InputDecoration(
                  labelText: 'Almacén de origen',
                  labelStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  prefixIcon: const Icon(
                    Icons.warehouse_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
                hint: const Text(
                  'Seleccione almacén de origen',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
                items:
                    data.warehouses
                        .map(
                          (w) => DropdownMenuItem(
                            value: w.id,
                            child: Text(
                              w.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: cubit.selectWarehouse,
              ),
              const SizedBox(height: 20),
              const Text(
                'Motivo de salida',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    reasons.entries.map((e) {
                      final selected = data.selectedReason == e.key;
                      return ChoiceChip(
                        avatar: Icon(
                          e.value,
                          size: 18,
                          color:
                              selected ? Colors.white : AppColors.textSecondary,
                        ),
                        label: Text(e.key),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (_) {
                          AppFeedbackService.selectionClick();
                          cubit.selectReason(e.key);
                        },
                        selectedColor: AppColors.primary,
                        backgroundColor: AppColors.background,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color:
                              selected ? Colors.white : AppColors.textPrimary,
                        ),
                        side: BorderSide(
                          color:
                              selected ? AppColors.primary : AppColors.border,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      );
                    }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
