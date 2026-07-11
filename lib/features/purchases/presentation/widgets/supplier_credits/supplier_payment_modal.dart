import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/features/purchases/data/models/supplier_credit_models.dart';
import 'package:inventory_store_app/features/purchases/data/repositories/supplier_credits_service.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class SupplierPaymentModal extends StatefulWidget {
  final SupplierCreditModel account;
  final VoidCallback onPaymentSaved;
  const SupplierPaymentModal({
    super.key,
    required this.account,
    required this.onPaymentSaved,
  });
  @override
  State<SupplierPaymentModal> createState() => _SupplierPaymentModalState();
}

class _SupplierPaymentModalState extends State<SupplierPaymentModal> {
  final _service = SupplierCreditsService();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isSaving = false;

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

  Future<void> _loadData() async {
    await Future.wait([_loadPendingOrders(), _loadAccounts()]);
  }

  Future<void> _loadPendingOrders() async {
    try {
      final resp = await _service.getPendingPurchaseOrders(
        widget.account.supplierId,
      );
      if (mounted) {
        setState(() {
          _pendingOrders = resp;
          _loadingOrders = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  Future<void> _loadAccounts() async {
    try {
      final resp = await _service.getFinancialAccounts();
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
    } catch (_) {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  Future<void> _checkActiveShift(String accountId) async {
    try {
      final shift = await _service.getActiveCashShift(accountId);
      if (mounted) {
        setState(() {
          _activeShift = shift;
        });
      }
    } catch (_) {
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

  Future<void> _savePayment() async {
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

    final amount = double.parse(_amountCtrl.text.trim());
    setState(() => _isSaving = true);

    try {
      final adminProfileId = await _service.getAdminProfileId();

      await _service.registerPayment(
        account: widget.account,
        amount: amount,
        selectedAccount: _selectedAccount!,
        selectedOrderId: _selectedOrderId,
        notes:
            _notesCtrl.text.trim().isEmpty
                ? "Pago registrado desde Admin Cuentas por Pagar"
                : _notesCtrl.text.trim(),
        pendingOrders: _pendingOrders,
        adminProfileId: adminProfileId,
        shiftId:
            _selectedAccount!.type == 'CAJA' && _activeShift != null
                ? _activeShift!['id'] as String?
                : null,
      );

      if (mounted) {
        AppSnackbar.show(
          context,
          message:
              'Pago de S/ ${amount.toStringAsFixed(2)} registrado exitosamente.',
          type: SnackbarType.success,
        );
        widget.onPaymentSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
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
        !_isSaving &&
        !isLoading &&
        !cajaSinTurno &&
        _selectedAccount != null &&
        _amountCtrl.text.trim().isNotEmpty &&
        _errorMessage == null;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                          fontWeight: FontWeight.bold,
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
                    (order['total_amount'] as num) - (order['amount_paid'] as num);
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
                      _errorMessage != null
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
            ElevatedButton(
              onPressed: isButtonEnabled ? _savePayment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                disabledBackgroundColor: Colors.grey.shade300,
                disabledForegroundColor: Colors.grey.shade500,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isSaving
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
            ),
          ],
        ),
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
