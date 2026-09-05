import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/di/injection_container.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_active_cash_shift_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_financial_accounts_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_pending_purchase_orders_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/register_supplier_payment_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_state.dart';

import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class SupplierPaymentSheet extends StatefulWidget {
  final SupplierCreditEntity account;
  final VoidCallback onPaymentSaved;
  final bool isDialog;
  const SupplierPaymentSheet({
    super.key,
    required this.account,
    required this.isDialog,
    required this.onPaymentSaved,
  });

  static Future<bool?> show(
    BuildContext context, {
    required SupplierCreditEntity account,
    required VoidCallback onPaymentSaved,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final cubit = context.read<SupplierCreditsCubit>();

    if (isMobile) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (_) => BlocProvider.value(
              value: cubit,
              child: SupplierPaymentSheet(
                account: account,
                isDialog: false,
                onPaymentSaved: onPaymentSaved,
              ),
            ),
      );
    } else {
      return showDialog<bool>(
        context: context,
        builder:
            (_) => BlocProvider.value(
              value: cubit,
              child: SupplierPaymentSheet(
                account: account,
                isDialog: true,
                onPaymentSaved: onPaymentSaved,
              ),
            ),
      );
    }
  }

  @override
  State<SupplierPaymentSheet> createState() => _SupplierPaymentSheetState();
}

class _SupplierPaymentSheetState extends State<SupplierPaymentSheet> {
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<Map<String, dynamic>> _pendingOrders = [];
  bool _loadingOrders = true;
  String? _selectedOrderId;
  String? _errorMessage;

  List<SupplierFinancialAccountOption> _accounts = [];
  SupplierFinancialAccountOption? _selectedAccount;
  bool _loadingAccounts = true;
  Map<String, dynamic>? _activeShift;
  String? _selectedQuickAmount;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadPendingOrders(), _loadAccounts()]);
  }

  Future<void> _loadPendingOrders() async {
    try {
      final respResult = await sl<GetPendingPurchaseOrdersUseCase>().call(
        widget.account.supplierId,
      );
      final resp = respResult.fold((l) => <Map<String, dynamic>>[], (r) => r);
      if (mounted) {
        setState(() {
          _pendingOrders = resp;
          _loadingOrders = false;
        });
      }
    } catch (e, st) {
      LoggerService.e(
        'Error cargando pedidos pendientes para el proveedor ${widget.account.supplierId}',
        tag: 'SUPPLIER_PAYMENT_SHEET',
        error: e,
        stackTrace: st,
      );
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  Future<void> _loadAccounts() async {
    try {
      final respResult = await sl<GetFinancialAccountsUseCase>().call();
      final resp = respResult.fold(
        (l) => <SupplierFinancialAccountOption>[],
        (r) => r,
      );
      if (mounted) {
        setState(() {
          _accounts = resp;
          if (_accounts.isNotEmpty) {
            _selectedAccount = _accounts.first;
            _loadingAccounts = false;
          } else {
            _loadingAccounts = false;
          }
        });
        if (_selectedAccount?.type == 'CAJA') {
          await _checkActiveShift(_selectedAccount!.id);
        }
      }
    } catch (e, st) {
      LoggerService.e(
        'Error cargando cuentas financieras',
        tag: 'SUPPLIER_PAYMENT_SHEET',
        error: e,
        stackTrace: st,
      );
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  Future<void> _checkActiveShift(String accountId) async {
    try {
      final shiftResult = await sl<GetActiveCashShiftUseCase>().call(accountId);
      final shift = shiftResult.fold((l) => <String, dynamic>{}, (r) => r);
      if (mounted) {
        setState(() {
          _activeShift = shift;
        });
      }
    } catch (e, st) {
      LoggerService.e(
        'Error verificando turno activo para la cuenta $accountId',
        tag: 'SUPPLIER_PAYMENT_SHEET',
        error: e,
        stackTrace: st,
      );
      if (mounted) setState(() => _activeShift = null);
    }
  }

  void _validarEntrada(String value, {bool fromQuick = false}) {
    if (!fromQuick && _selectedQuickAmount != null) {
      setState(() => _selectedQuickAmount = null);
    }
    if (value.trim().isEmpty) {
      setState(() => _errorMessage = null);
      return;
    }
    final amount = double.tryParse(value.trim());
    if (amount == null) {
      setState(() => _errorMessage = 'Monto inválido');
      return;
    }
    if (amount <= 0) {
      setState(() => _errorMessage = 'El monto debe ser mayor a 0');
      return;
    }

    if (_selectedOrderId != null) {
      final order = _pendingOrders.firstWhere(
        (o) => o['id'] == _selectedOrderId,
      );
      final pending =
          (order['total_amount'] as num) - (order['amount_paid'] as num);
      if (amount > pending) {
        setState(
          () =>
              _errorMessage =
                  'El monto supera la deuda del pedido (S/ ${pending.toStringAsFixed(2)})',
        );
        return;
      }
    } else {
      if (amount > widget.account.currentDebt) {
        setState(
          () =>
              _errorMessage =
                  'El monto supera la deuda total (S/ ${widget.account.currentDebt.toStringAsFixed(2)})',
        );
        return;
      }
    }

    setState(() => _errorMessage = null);
  }

  void _savePayment() {
    if (_errorMessage != null || _amountCtrl.text.isEmpty) return;

    if (_selectedAccount == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona una cuenta de salida.',
        type: SnackbarType.warning,
      );
      return;
    }

    if (_selectedAccount!.type == 'CAJA' && _activeShift == null) {
      AppSnackbar.show(
        context,
        message: 'La cuenta CAJA no tiene un turno abierto.',
        type: SnackbarType.error,
      );
      return;
    }

    // Validar saldo suficiente
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      AppSnackbar.show(
        context,
        message: 'Ingresa un monto válido mayor a 0.',
        type: SnackbarType.error,
      );
      return;
    }
    if (_selectedAccount!.balance < amount) {
      AppSnackbar.show(
        context,
        message:
            'Saldo insuficiente. La cuenta tiene S/ ${_selectedAccount!.balance.toStringAsFixed(2)} y el monto requerido es S/ ${amount.toStringAsFixed(2)}.',
        type: SnackbarType.error,
      );
      return;
    }

    final notesText =
        _notesCtrl.text.trim().isEmpty
            ? 'Pago registrado desde Admin Cuentas por Pagar'
            : _notesCtrl.text.trim();

    final params = RegisterSupplierPaymentParams(
      supplierId: widget.account.supplierId,
      creditId: widget.account.creditId,
      amount: amount,
      accountId: _selectedAccount?.id,
      orderId: _selectedOrderId,
      notes: notesText,
      shiftId:
          _selectedAccount?.type == 'CAJA' && _activeShift != null
              ? _activeShift!['id'] as String?
              : null,
    );

    context.read<SupplierCreditsCubit>().registerPayment(params);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final debt = widget.account.currentDebt;
    final amountToPay = double.tryParse(_amountCtrl.text) ?? 0.0;
    final showSummary = amountToPay > 0 && _errorMessage == null;
    final bool isLoading = _loadingOrders || _loadingAccounts;
    final bool cajaSinTurno =
        _selectedAccount?.type == 'CAJA' && _activeShift == null;
    final bool isButtonEnabled =
        !isLoading &&
        !cajaSinTurno &&
        _selectedAccount != null &&
        _amountCtrl.text.trim().isNotEmpty &&
        _errorMessage == null;

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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
          if (_loadingOrders)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            _OrderSelectionTile(
              label: 'Distribuir automáticamente',
              sublabel: 'FIFO — salda los pedidos más antiguos primero',
              isSelected: _selectedOrderId == null,
              onTap: () {
                setState(() => _selectedOrderId = null);
                _validarEntrada(_amountCtrl.text);
              },
            ),
            ..._pendingOrders.map((order) {
              final orderId = order['id'] as String;
              final shortId = orderId.substring(0, 8).toUpperCase();
              final pending =
                  (order['total_amount'] as num) -
                  (order['amount_paid'] as num);
              final isParcial = order['payment_status'] == 'PARTIAL';

              return _OrderSelectionTile(
                label: 'Pedido #$shortId',
                sublabel:
                    isParcial
                        ? 'Pago parcial · Pendiente S/ ${pending.toStringAsFixed(2)}'
                        : 'Sin pagar · S/ ${pending.toStringAsFixed(2)}',
                isSelected: _selectedOrderId == orderId,
                onTap: () {
                  setState(() {
                    _selectedOrderId = orderId;
                    final valText = pending.toStringAsFixed(2);
                    _amountCtrl.text = valText;
                    _validarEntrada(valText);
                  });
                },
              );
            }),
            if (_pendingOrders.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: AppColors.textMuted,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No se encontraron pedidos pendientes. El pago se aplicará a la deuda general.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
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
                  _QuickAmountChip(
                    label: 'S/ 50',
                    isSelected: _selectedQuickAmount == '50.00',
                    onTap: () {
                      setState(() => _selectedQuickAmount = '50.00');
                      _amountCtrl.text = '50.00';
                      _validarEntrada('50.00', fromQuick: true);
                    },
                  ),
                if (debt >= 100)
                  _QuickAmountChip(
                    label: 'S/ 100',
                    isSelected: _selectedQuickAmount == '100.00',
                    onTap: () {
                      setState(() => _selectedQuickAmount = '100.00');
                      _amountCtrl.text = '100.00';
                      _validarEntrada('100.00', fromQuick: true);
                    },
                  ),
                if (debt >= 200)
                  _QuickAmountChip(
                    label: 'S/ 200',
                    isSelected: _selectedQuickAmount == '200.00',
                    onTap: () {
                      setState(() => _selectedQuickAmount = '200.00');
                      _amountCtrl.text = '200.00';
                      _validarEntrada('200.00', fromQuick: true);
                    },
                  ),
                _QuickAmountChip(
                  label: 'Total (S/ ${debt.toStringAsFixed(2)})',
                  isSelected: _selectedQuickAmount == debt.toStringAsFixed(2),
                  isTotalChip: true,
                  onTap: () {
                    final v = debt.toStringAsFixed(2);
                    setState(() => _selectedQuickAmount = v);
                    _amountCtrl.text = v;
                    _validarEntrada(v, fromQuick: true);
                  },
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
                    _errorMessage != null ? AppColors.danger : AppColors.border,
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
              onChanged: _validarEntrada,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Ej. 50.00',
                errorText: _errorMessage,
                errorMaxLines: 2,
                prefixIcon: Icon(
                  Icons.attach_money_rounded,
                  color:
                      _errorMessage != null
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
          if (_loadingAccounts)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_accounts.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_rounded,
                    size: 14,
                    color: AppColors.danger,
                  ),
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
            )
          else
            DropdownButtonFormField<SupplierFinancialAccountOption>(
              initialValue: _selectedAccount,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              items:
                  _accounts
                      .map(
                        (a) => DropdownMenuItem(
                          value: a,
                          child: Text(
                            '${a.name} (S/ ${a.balance.toStringAsFixed(2)})',
                            style: TextStyle(
                              color:
                                  a.balance > 0
                                      ? Colors.black
                                      : AppColors.danger,
                            ),
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (v) {
                setState(() => _selectedAccount = v);
                if (v!.type == 'CAJA') _checkActiveShift(v.id);
                _validarEntrada(_amountCtrl.text);
              },
            ),
          if (_selectedAccount?.type == 'CAJA' &&
              _activeShift == null &&
              !_loadingAccounts) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.3),
                ),
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
          ],
          if (_selectedAccount?.type == 'CAJA' && _activeShift != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          ],
          const SizedBox(height: 24),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: showSummary ? _buildSummary(amountToPay) : const SizedBox(),
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
                    current is SupplierCreditSaveSuccess ||
                    current is SupplierCreditSaveError,
            listener: (context, state) {
              if (state is SupplierCreditSaveError) {
                AppSnackbar.show(
                  context,
                  message: state.message,
                  type: SnackbarType.error,
                );
              } else if (state is SupplierCreditSaveSuccess) {
                AppSnackbar.show(
                  context,
                  message: state.message,
                  type: SnackbarType.success,
                );
                widget.onPaymentSaved();
                Navigator.pop(context);
              }
            },
            builder: (context, state) {
              final isSaving = state is SupplierCreditSaving;
              return ElevatedButton(
                onPressed: (isButtonEnabled && !isSaving) ? _savePayment : null,
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
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Container(
          width: 500,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          padding: const EdgeInsets.all(24),
          child: sheetContent,
        ),
      );
    }

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
        child: sheetContent,
      ),
    );
  }

  Widget _buildSummary(double amountToPay) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resumen de la operación',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pago total:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'S/ ${amountToPay.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Deuda restante:',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    'S/ ${(widget.account.currentDebt - amountToPay).clamp(0.0, double.infinity).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _OrderSelectionTile extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool isSelected;
  final VoidCallback onTap;

  const _OrderSelectionTile({
    required this.label,
    required this.sublabel,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.tealLight : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.teal : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppColors.teal : AppColors.textMuted,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color:
                          isSelected
                              ? AppColors.tealDark
                              : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isSelected ? AppColors.teal : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isTotalChip;
  final VoidCallback onTap;

  const _QuickAmountChip({
    required this.label,
    required this.isSelected,
    this.isTotalChip = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? (isTotalChip ? AppColors.danger : AppColors.teal)
                  : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
