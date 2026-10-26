import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_active_cash_shift_usecase.dart';

/// Resultado inmutable devuelto tras la confirmación del pago en [_OrderPaymentDialog].
class PaymentDialogResult {
  final double amount;
  final String accountId;
  final String? shiftId;

  const PaymentDialogResult({
    required this.amount,
    required this.accountId,
    this.shiftId,
  });
}

/// Diálogo modal para registrar abonos o amortizaciones a órdenes de compra.
class OrderPaymentDialog extends StatefulWidget {
  final String supplierName;
  final double pending;
  final List<SupplierFinancialAccountOption> accounts;

  const OrderPaymentDialog({
    super.key,
    required this.supplierName,
    required this.pending,
    required this.accounts,
  });

  static Future<PaymentDialogResult?> show(
    BuildContext context, {
    required String supplierName,
    required double pending,
    required List<SupplierFinancialAccountOption> accounts,
  }) {
    return showDialog<PaymentDialogResult>(
      context: context,
      builder:
          (ctx) => OrderPaymentDialog(
            supplierName: supplierName,
            pending: pending,
            accounts: accounts,
          ),
    );
  }

  @override
  State<OrderPaymentDialog> createState() => _OrderPaymentDialogState();
}

class _OrderPaymentDialogState extends State<OrderPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountCtrl;
  late String _selectedAccountId;
  bool _checkingShift = false;
  Map<String, dynamic>? _activeShift;
  int _shiftRequestId = 0;

  @override
  void initState() {
    super.initState();
    _selectedAccountId = widget.accounts.first.id;
    _amountCtrl = TextEditingController(
      text: widget.pending.toStringAsFixed(2),
    );

    final initialAcc = widget.accounts.first;
    if (initialAcc.type == 'CAJA') {
      _checkActiveShift(initialAcc.id);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkActiveShift(String accountId) async {
    final currentReqId = ++_shiftRequestId;
    setState(() => _checkingShift = true);
    try {
      final shiftResult = await sl<GetActiveCashShiftUseCase>().call(accountId);
      if (currentReqId != _shiftRequestId || !mounted) return;
      final shift = shiftResult.fold((l) => null, (r) => r);
      setState(() {
        _activeShift = (shift != null && shift.isNotEmpty) ? shift : null;
        _checkingShift = false;
      });
    } catch (e, st) {
      LoggerService.e(
        'Error verificando turno activo para la cuenta $accountId',
        tag: 'ORDER_PAYMENT_DIALOG',
        error: e,
        stackTrace: st,
      );
      if (currentReqId == _shiftRequestId && mounted) {
        setState(() {
          _activeShift = null;
          _checkingShift = false;
        });
      }
    }
  }

  void _applyPercentage(double fraction) {
    final val = widget.pending * fraction;
    setState(() {
      _amountCtrl.text = val.toStringAsFixed(2);
      _amountCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _amountCtrl.text.length),
      );
    });
    _formKey.currentState?.validate();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final cleanText = _amountCtrl.text.trim().replaceAll(',', '.');
    final payAmount = double.tryParse(cleanText) ?? 0.0;
    if (payAmount <= 0) {
      AppSnackbar.show(
        context,
        message: 'Ingrese un monto válido mayor a 0.',
        type: SnackbarType.error,
      );
      return;
    }

    if (payAmount > widget.pending + 0.001) {
      AppSnackbar.show(
        context,
        message:
            'El monto a pagar (S/ ${payAmount.toStringAsFixed(2)}) no puede superar la deuda pendiente (S/ ${widget.pending.toStringAsFixed(2)}).',
        type: SnackbarType.error,
      );
      return;
    }

    final selAcc = widget.accounts.firstWhere(
      (a) => a.id == _selectedAccountId,
      orElse: () => widget.accounts.first,
    );

    if (selAcc.type == 'CAJA' && _activeShift == null) {
      AppSnackbar.show(
        context,
        message:
            'La caja seleccionada no tiene un turno abierto. Debe abrir turno antes de registrar el pago.',
        type: SnackbarType.error,
      );
      return;
    }

    if (selAcc.balance < payAmount) {
      AppSnackbar.show(
        context,
        message:
            'Saldo insuficiente en la cuenta "${selAcc.name}". Saldo disponible: S/ ${selAcc.balance.toStringAsFixed(2)}, Monto a pagar: S/ ${payAmount.toStringAsFixed(2)}.',
        type: SnackbarType.error,
      );
      return;
    }

    final shiftId =
        (selAcc.type == 'CAJA' && _activeShift != null)
            ? _activeShift!['id']?.toString()
            : null;

    Navigator.pop(
      context,
      PaymentDialogResult(
        amount: payAmount,
        accountId: _selectedAccountId,
        shiftId: shiftId,
      ),
    );
  }

  Widget _buildQuickPctChip(String label, double fraction) {
    final expectedVal = (widget.pending * fraction).toStringAsFixed(2);
    final isSelected = _amountCtrl.text == expectedVal;

    return Expanded(
      child: InkWell(
        onTap: () => _applyPercentage(fraction),
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surface,
            border: Border.all(
              color:
                  isSelected
                      ? AppColors.primary
                      : AppColors.border.withValues(alpha: 0.7),
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedAcc = widget.accounts.firstWhere(
      (a) => a.id == _selectedAccountId,
      orElse: () => widget.accounts.first,
    );

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.payments_rounded,
              color: AppColors.success,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Registrar Pago de Orden',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 2),
                Text(
                  'Amortización directa a cuenta por pagar',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Panel Proveedor y Deuda
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'PROVEEDOR',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.supplierName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'DEUDA PENDIENTE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'S/ ${widget.pending.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Cuenta Origen (Caja / Banco):',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedAccountId,
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                items:
                    widget.accounts.map((acc) {
                      return DropdownMenuItem<String>(
                        value: acc.id,
                        child: Text(
                          '${acc.name} (Saldo: S/ ${acc.balance.toStringAsFixed(2)})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedAccountId = val;
                      _activeShift = null;
                    });
                    final acc = widget.accounts.firstWhere((a) => a.id == val);
                    if (acc.type == 'CAJA') {
                      _checkActiveShift(acc.id);
                    }
                  }
                },
              ),
              if (selectedAcc.type == 'CAJA') ...[
                const SizedBox(height: 8),
                if (_checkingShift)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(
                          width: 13,
                          height: 13,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Verificando turno de caja...',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_activeShift == null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 13,
                          color: AppColors.danger,
                        ),
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
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 13,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Turno abierto · Se registrará en el turno activo',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Monto a pagar:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Saldo: S/ ${selectedAcc.balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Chips de porcentaje rápido
              Row(
                children: [
                  _buildQuickPctChip('100% (Total)', 1.0),
                  const SizedBox(width: 8),
                  _buildQuickPctChip('50%', 0.5),
                  const SizedBox(width: 8),
                  _buildQuickPctChip('25%', 0.25),
                ],
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Text(
                      'S/',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingrese un monto a pagar';
                  }
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'El monto debe ser mayor a 0';
                  }
                  if (parsed > widget.pending + 0.001) {
                    return 'Excede la deuda (S/ ${widget.pending.toStringAsFixed(2)})';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey.shade300,
            disabledForegroundColor: Colors.grey.shade500,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed:
              (selectedAcc.type == 'CAJA' &&
                      (_checkingShift || _activeShift == null))
                  ? null
                  : _submit,
          child: const Text(
            'Confirmar Pago',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
