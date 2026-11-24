import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/adaptive_detail_sheet.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_state.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_payment_form_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_payment_form_state.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_payment_order_picker.dart';
import 'package:inventory_store_app/features/purchases/presentation/widgets/supplier_credits/supplier_payment_summary_card.dart';

class SupplierPaymentSheet extends StatefulWidget {
  final SupplierCreditEntity account;
  final bool isDialog;

  const SupplierPaymentSheet({
    super.key,
    required this.account,
    required this.isDialog,
  });

  static Future<bool?> show(
    BuildContext context, {
    required SupplierCreditEntity account,
  }) {
    final creditsCubit = context.read<SupplierCreditsCubit>();

    return AdaptiveDetailSheet.show<bool>(
      context,
      desktopWidth: 540.0,
      barrierLabel: 'Cerrar registro de pago',
      builder:
          (ctx) => MultiBlocProvider(
            providers: [
              BlocProvider.value(value: creditsCubit),
              BlocProvider(
                create: (_) => sl<SupplierPaymentFormCubit>()..init(account),
              ),
            ],
            child: SupplierPaymentSheet(
              account: account,
              isDialog: AdaptiveDetailSheet.isSideSheet(ctx),
            ),
          ),
    );
  }

  @override
  State<SupplierPaymentSheet> createState() => _SupplierPaymentSheetState();
}

class _SupplierPaymentSheetState extends State<SupplierPaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _syncAmountController(String nextText) {
    if (_amountCtrl.text != nextText) {
      _amountCtrl.value = TextEditingValue(
        text: nextText,
        selection: TextSelection.collapsed(offset: nextText.length),
      );
    }
  }

  void _submitPayment(SupplierPaymentFormCubit formCubit) {
    final preValidation = formCubit.preSubmitValidationError();
    if (preValidation != null) {
      AppSnackbar.show(
        context,
        message: preValidation,
        type: SnackbarType.error,
      );
      return;
    }

    final params = formCubit.buildParams(_notesCtrl.text);
    context.read<SupplierCreditsCubit>().registerPayment(params);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final debt = widget.account.currentDebt;

    return BlocConsumer<SupplierPaymentFormCubit, SupplierPaymentFormState>(
      listenWhen: (prev, curr) => prev.amountText != curr.amountText,
      listener: (_, state) => _syncAmountController(state.amountText),
      builder: (context, formState) {
        final formCubit = context.read<SupplierPaymentFormCubit>();

        final sheetContent = SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.isDialog)
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              Row(
                children: [
                  const Icon(Icons.payments_rounded, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Pagar al proveedor',
                          style: TextStyle(
                            fontSize: 17,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          widget.account.supplierName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.money_off_rounded,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Deuda actual',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'S/ ${debt.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '¿A qué pedido aplicar el pago?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              SupplierPaymentOrderPicker(
                loadingOrders: formState.loadingOrders,
                errorMessage: formState.ordersFailure?.message,
                pendingOrders: formState.pendingOrders,
                selectedOrderId: formState.selectedOrderId,
                onSelectOrder: formCubit.selectOrder,
                onRetry: formCubit.reloadAll,
              ),
              const SizedBox(height: 14),
              if (debt > 0) ...[
                const Text(
                  'Monto rápido',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (debt >= 50)
                      QuickAmountChip(
                        label: 'S/ 50',
                        isSelected: formState.selectedQuickAmount == '50.00',
                        onTap: () => formCubit.selectQuickAmount('50.00'),
                      ),
                    if (debt >= 100)
                      QuickAmountChip(
                        label: 'S/ 100',
                        isSelected: formState.selectedQuickAmount == '100.00',
                        onTap: () => formCubit.selectQuickAmount('100.00'),
                      ),
                    if (debt >= 200)
                      QuickAmountChip(
                        label: 'S/ 200',
                        isSelected: formState.selectedQuickAmount == '200.00',
                        onTap: () => formCubit.selectQuickAmount('200.00'),
                      ),
                    QuickAmountChip(
                      label: 'Total (S/ ${debt.toStringAsFixed(2)})',
                      isSelected:
                          formState.selectedQuickAmount ==
                          debt.toStringAsFixed(2),
                      isTotalChip: true,
                      onTap:
                          () => formCubit.selectQuickAmount(
                            debt.toStringAsFixed(2),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
              const Text(
                'Monto del abono (S/)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        formState.amountError != null
                            ? AppColors.danger
                            : AppColors.border,
                  ),
                ),
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: formCubit.validateAmount,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ej. 50.00',
                    errorText: formState.amountError,
                    errorMaxLines: 2,
                    prefixIcon: Icon(
                      Icons.attach_money_rounded,
                      color:
                          formState.amountError != null
                              ? AppColors.danger
                              : AppColors.textMuted,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Cuenta desde donde se paga',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              _buildAccountSection(formState, formCubit),
              _buildCashShiftBanner(formState, formCubit),
              const SizedBox(height: 24),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child:
                    formState.showSummary
                        ? SupplierPaymentSummaryCard(
                          amountToPay: formState.parsedAmount,
                          currentDebt: debt,
                        )
                        : const SizedBox(),
              ),
              const Text(
                'Notas (opcional)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Ej. Pago del pedido #123...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              BlocConsumer<SupplierCreditsCubit, SupplierCreditsState>(
                listenWhen:
                    (previous, current) =>
                        previous.mutationStatus != current.mutationStatus &&
                        (current.mutationStatus ==
                                SupplierCreditMutationStatus.success ||
                            current.mutationStatus ==
                                SupplierCreditMutationStatus.failure),
                listener: (context, state) {
                  if (state.mutationStatus ==
                      SupplierCreditMutationStatus.success) {
                    Navigator.pop(context, true);
                  }
                },
                builder: (context, creditsState) {
                  final isSaving =
                      creditsState.mutationStatus ==
                      SupplierCreditMutationStatus.submitting;
                  return ElevatedButton(
                    onPressed:
                        (formState.canSubmit && !isSaving)
                            ? () => _submitPayment(formCubit)
                            : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade500,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        isSaving
                            ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                            : const Text(
                              'Confirmar abono',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                  );
                },
              ),
            ],
          ),
        );

        if (widget.isDialog) {
          return Padding(padding: const EdgeInsets.all(24), child: sheetContent);
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
          child: sheetContent,
        );
      },
    );
  }

  Widget _buildAccountSection(
    SupplierPaymentFormState formState,
    SupplierPaymentFormCubit formCubit,
  ) {
    if (formState.loadingAccounts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (formState.accountsFailure != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.warning_rounded,
              size: 14,
              color: AppColors.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                formState.accountsFailure!.message,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: formCubit.reloadAll,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (formState.accounts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_rounded, size: 14, color: AppColors.danger),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'No hay cuentas financieras activas. Crea una primero.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<SupplierFinancialAccountOption>(
      initialValue: formState.selectedAccount,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      items:
          formState.accounts
              .map(
                (a) => DropdownMenuItem(
                  value: a,
                  child: Text(
                    '${a.name} (S/ ${a.balance.toStringAsFixed(2)})',
                    style: TextStyle(
                      color: a.balance > 0 ? Colors.black : AppColors.danger,
                    ),
                  ),
                ),
              )
              .toList(),
      onChanged: formCubit.selectAccount,
    );
  }

  Widget _buildCashShiftBanner(
    SupplierPaymentFormState formState,
    SupplierPaymentFormCubit formCubit,
  ) {
    if (formState.selectedAccount?.type != 'CAJA' ||
        formState.loadingAccounts) {
      return const SizedBox.shrink();
    }

    if (formState.shiftStatus == CashShiftStatus.loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 8),
            Text(
              'Verificando turno de caja...',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (formState.shiftStatus == CashShiftStatus.error) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.dangerLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 14,
                color: AppColors.danger,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  formState.shiftFailure?.message ??
                      'Error al verificar turno de caja.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed:
                    () => formCubit.checkActiveShift(
                      formState.selectedAccount!.id,
                    ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Reintentar', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      );
    }

    if (formState.shiftStatus == CashShiftStatus.closed) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.dangerLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock_rounded, size: 13, color: AppColors.danger),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Esta caja no tiene un turno abierto. Abre el turno antes de registrar el pago.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (formState.shiftStatus == CashShiftStatus.open &&
        formState.activeShift != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.successLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 13,
                color: AppColors.success,
              ),
              SizedBox(width: 6),
              Text(
                'Turno abierto · Se registrará en el turno activo',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
