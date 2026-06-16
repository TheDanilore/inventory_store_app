import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/models/supplier_credit_models.dart';
import 'package:inventory_store_app/services/admin/supplier_credits_service.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

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
      final resp = await _service.getPendingPurchaseOrders(widget.account.supplierId);
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

  void _validarEntrada(String value) {
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
      final order = _pendingOrders.firstWhere((o) => o['id'] == _selectedOrderId);
      final pending = (order['total_amount'] as num) - (order['amount_paid'] as num);
      if (amount > pending) {
        setState(() => _errorMessage = 'El monto supera la deuda del pedido (S/ ${pending.toStringAsFixed(2)})');
        return;
      }
    } else {
      if (amount > widget.account.currentDebt) {
        setState(() => _errorMessage = 'El monto supera la deuda total (S/ ${widget.account.currentDebt.toStringAsFixed(2)})');
        return;
      }
    }

    setState(() => _errorMessage = null);
  }

  Future<void> _savePayment() async {
    if (_errorMessage != null || _amountCtrl.text.isEmpty) return;

    if (_selectedAccount == null) {
      AppSnackbar.show(context, message: 'Selecciona una cuenta de salida.', type: SnackbarType.warning);
      return;
    }

    if (_selectedAccount!.type == 'CAJA' && _activeShift == null) {
      AppSnackbar.show(context, message: 'La cuenta CAJA no tiene un turno abierto.', type: SnackbarType.error);
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
        notes: _notesCtrl.text.trim().isEmpty ? "Pago registrado desde Admin Cuentas por Pagar" : _notesCtrl.text.trim(),
        pendingOrders: _pendingOrders,
        adminProfileId: adminProfileId,
        shiftId: _selectedAccount!.type == 'CAJA' && _activeShift != null ? _activeShift!['id'] as String? : null,
      );

      if (mounted) {
        AppSnackbar.show(context, message: 'Pago de S/ ${amount.toStringAsFixed(2)} registrado exitosamente.', type: SnackbarType.success);
        widget.onPaymentSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, message: 'Error: $e', type: SnackbarType.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final amountToPay = double.tryParse(_amountCtrl.text) ?? 0.0;
    final showSummary = amountToPay > 0 && _errorMessage == null;

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
                width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
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
                      const Text('Pagar al proveedor', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text(widget.account.supplierName, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.money_off_rounded, color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  const Text('Deuda actual', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
                  const Spacer(),
                  Text('S/ ${widget.account.currentDebt.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.danger)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('¿A qué pedido aplicar el pago?', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            if (_loadingOrders)
              const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
            else
              Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  _OrderChip(
                    label: 'Distribuir (Pago General)',
                    isSelected: _selectedOrderId == null,
                    isTotalChip: true,
                    onTap: () {
                      setState(() {
                        _selectedOrderId = null;
                        _validarEntrada(_amountCtrl.text);
                      });
                    },
                  ),
                  ..._pendingOrders.map((o) {
                    final pending = (o['total_amount'] as num) - (o['amount_paid'] as num);
                    return _OrderChip(
                      label: 'Orden #${o['id'].toString().substring(0, 6).toUpperCase()} (S/ ${pending.toStringAsFixed(2)})',
                      isSelected: _selectedOrderId == o['id'],
                      isTotalChip: false,
                      onTap: () {
                        setState(() {
                          _selectedOrderId = o['id'] as String;
                          _validarEntrada(_amountCtrl.text);
                        });
                      },
                    );
                  }),
                ],
              ),
            const SizedBox(height: 16),
            const Text('Cuenta desde donde se paga', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            if (_loadingAccounts)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<SupplierFinancialAccountOption>(
                initialValue: _selectedAccount,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: _accounts.map((a) => DropdownMenuItem(
                  value: a,
                  child: Text('${a.name} (S/ ${a.balance.toStringAsFixed(2)})', style: TextStyle(color: a.balance > 0 ? Colors.black : AppColors.danger)),
                )).toList(),
                onChanged: (v) {
                  setState(() => _selectedAccount = v);
                  if (v!.type == 'CAJA') _checkActiveShift(v.id);
                  _validarEntrada(_amountCtrl.text);
                },
              ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: _errorMessage != null ? AppColors.danger : AppColors.border)),
              child: TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                onChanged: _validarEntrada,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Monto a pagar (Ej. 100.00)', errorText: _errorMessage,
                  prefixIcon: Icon(Icons.attach_money_rounded, color: _errorMessage != null ? AppColors.danger : AppColors.textMuted),
                  border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (showSummary) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.success.withValues(alpha: 0.3))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Resumen de la operación', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [const Text('Pago total:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)), Text('S/ ${amountToPay.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.success))],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [const Text('Deuda restante:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)), Text('S/ ${(widget.account.currentDebt - amountToPay).clamp(0.0, double.infinity).toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary))],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            ElevatedButton(
              onPressed: (_errorMessage == null && _amountCtrl.text.isNotEmpty && !_isSaving) ? _savePayment : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white)) : const Text('Confirmar abono', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isTotalChip;
  final VoidCallback onTap;

  const _OrderChip({
    required this.label,
    required this.isSelected,
    required this.isTotalChip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    Color textColor;

    if (isSelected) {
      bgColor = isTotalChip ? AppColors.success.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1);
      borderColor = isTotalChip ? AppColors.success : Colors.blue;
      textColor = isTotalChip ? Colors.green.shade800 : Colors.blue.shade800;
    } else {
      bgColor = AppColors.bg;
      borderColor = AppColors.border;
      textColor = AppColors.textSecondary;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          boxShadow: isSelected ? [BoxShadow(color: (isTotalChip ? AppColors.success : Colors.blue).withValues(alpha: 0.22), blurRadius: 6, offset: const Offset(0, 2))] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[Icon(Icons.check_rounded, size: 11, color: textColor), const SizedBox(width: 4)],
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
          ],
        ),
      ),
    );
  }
}
