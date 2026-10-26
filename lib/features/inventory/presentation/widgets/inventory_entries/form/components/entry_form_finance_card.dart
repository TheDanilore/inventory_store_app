import 'package:flutter/material.dart';
import 'package:inventory_store_app/core/services/app_feedback_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form/inventory_entry_form_cubit.dart';
import 'package:inventory_store_app/features/inventory/presentation/bloc/inventory_entry_form/inventory_entry_form_state.dart';
import 'package:inventory_store_app/features/inventory/presentation/widgets/inventory_entries/form/components/entry_form_section_card.dart';

/// Tarjeta de configuración financiera y modalidad de pago (Contado, Crédito, Ajuste).
class EntryFormFinanceCard extends StatelessWidget {
  final InventoryEntryFormState state;
  final InventoryEntryFormCubit cubit;

  const EntryFormFinanceCard({
    super.key,
    required this.state,
    required this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    final isCredit = state.paymentMode == 'CRÉDITO';
    final selectedAcc =
        state.accounts
            .where((a) => a.id == state.selectedAccountId)
            .firstOrNull;
    final selectedAccId = selectedAcc?.id;

    final isCaja = selectedAcc?.type.toUpperCase() == 'CAJA';
    final hasOpenShift =
        selectedAccId != null &&
        state.activeShiftsByAccount.containsKey(selectedAccId);

    final totalAmount = state.items.fold<double>(
      0.0,
      (sum, item) => sum + (item.quantity * item.unitCost),
    );
    final isInsufficientBalance =
        selectedAcc != null &&
        state.items.isNotEmpty &&
        selectedAcc.balance < totalAmount;

    return EntryFormSectionCard(
      highlightColor: isCredit ? Colors.purple.shade50 : null,
      borderColor: isCredit ? Colors.purple.shade200 : AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EntryFormSectionTitle(
            icon: Icons.payments_rounded,
            title: 'Modo de pago',
            iconColor: isCredit ? Colors.purple.shade600 : AppColors.primary,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'CONTADO', label: Text('Contado')),
                ButtonSegment(value: 'CRÉDITO', label: Text('Crédito')),
                ButtonSegment(value: 'AJUSTE', label: Text('Ajuste')),
              ],
              selected: {state.paymentMode},
              onSelectionChanged: (selection) {
                AppFeedbackService.selectionClick();
                cubit.setPaymentMode(selection.first);
              },
              style: SegmentedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.textSecondary,
                selectedBackgroundColor:
                    isCredit ? Colors.purple.shade600 : AppColors.primary,
                selectedForegroundColor: Colors.white,
                side: const BorderSide(color: AppColors.border),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child:
                state.paymentMode == 'CONTADO'
                    ? Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String>(
                            key: ValueKey(
                              'acc_${selectedAccId}_${state.accounts.length}',
                            ),
                            initialValue: selectedAccId,
                            isExpanded: true,
                            icon: const Icon(Icons.expand_more_rounded),
                            decoration: entryFormDropdownDecoration(
                              'Cuenta a debitar',
                              icon: Icons.account_balance_wallet_rounded,
                            ),
                            hint: const Text(
                              'Seleccione cuenta a debitar',
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 14,
                              ),
                            ),
                            items:
                                state.accounts.map((acc) {
                                  return DropdownMenuItem(
                                    value: acc.id,
                                    child: Text(
                                      '${acc.name} (Saldo: S/ ${acc.balance.toStringAsFixed(2)})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  );
                                }).toList(),
                            onChanged: cubit.setAccount,
                            validator: (val) {
                              if (state.paymentMode == 'CONTADO') {
                                if (val == null || val.isEmpty) {
                                  return 'Seleccione la cuenta a debitar';
                                }
                                final acc =
                                    state.accounts
                                        .where((a) => a.id == val)
                                        .firstOrNull;
                                if (acc != null &&
                                    acc.type.toUpperCase() == 'CAJA' &&
                                    !state.activeShiftsByAccount.containsKey(
                                      acc.id,
                                    )) {
                                  return 'La caja seleccionada no tiene un turno abierto';
                                }
                              }
                              return null;
                            },
                          ),
                          if (selectedAcc != null &&
                              isCaja &&
                              !hasOpenShift) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.warning.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.warning_amber_rounded,
                                    color: AppColors.warning,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Caja sin turno abierto ("${selectedAcc.name}")',
                                          style: const TextStyle(
                                            color: AppColors.warning,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Debes abrir un turno de caja para registrar pagos al contado.',
                                          style: TextStyle(
                                            color: AppColors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Refrescar estado de turnos',
                                    icon: const Icon(
                                      Icons.refresh_rounded,
                                      size: 18,
                                      color: AppColors.warning,
                                    ),
                                    onPressed: () => cubit.refreshCashShifts(),
                                  ),
                                ],
                              ),
                            ),
                          ] else if (selectedAcc != null &&
                              isCaja &&
                              hasOpenShift) ...[
                            const SizedBox(height: 8),
                            const Row(
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: AppColors.success,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Turno de caja abierto y disponible',
                                  style: TextStyle(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (isInsufficientBalance) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.danger.withValues(
                                    alpha: 0.35,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    color: AppColors.danger,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Saldo insuficiente en "${selectedAcc.name}". Disponible: S/ ${selectedAcc.balance.toStringAsFixed(2)} · Requerido: S/ ${totalAmount.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        color: AppColors.danger,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
