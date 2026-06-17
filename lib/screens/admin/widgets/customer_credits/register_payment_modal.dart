import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:inventory_store_app/models/customer_credit_models.dart';
import 'package:inventory_store_app/services/admin/customer_credits_service.dart';
import 'package:inventory_store_app/providers/app_config_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

class RegisterPaymentModal extends StatefulWidget {
  final CreditAccountModel account;
  final VoidCallback onPaymentSaved;

  const RegisterPaymentModal({
    super.key,
    required this.account,
    required this.onPaymentSaved,
  });

  @override
  State<RegisterPaymentModal> createState() => _RegisterPaymentModalState();
}

class _RegisterPaymentModalState extends State<RegisterPaymentModal> {
  final _service = CustomerCreditsService();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isSaving = false;

  List<Map<String, dynamic>> _pendingOrders = [];
  bool _loadingOrders = true;
  String? _selectedOrderId;

  String? _errorMessage;
  String? _selectedQuickAmount;

  List<FinancialAccountOption> _accounts = [];
  FinancialAccountOption? _selectedAccount;
  bool _loadingAccounts = true;
  Map<String, dynamic>? _activeShift;

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
      final orders = await _service.getPendingOrders(widget.account.profileId);
      if (mounted) {
        setState(() {
          _pendingOrders = orders;
          _loadingOrders = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await _service.getFinancialAccounts();
      if (mounted) {
        setState(() {
          _accounts = accounts;
          if (accounts.isNotEmpty) {
            _selectedAccount = accounts.first;
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
      if (mounted) setState(() => _activeShift = shift);
    } catch (_) {
      if (mounted) setState(() => _activeShift = null);
    }
  }

  Future<void> _onAccountChanged(FinancialAccountOption account) async {
    setState(() {
      _selectedAccount = account;
      _activeShift = null;
    });
    if (account.type == 'CAJA') {
      await _checkActiveShift(account.id);
    }
  }

  double _pendingOf(Map<String, dynamic> order) {
    final total = (order['total_amount'] as num).toDouble();
    final paid = (order['amount_paid'] as num).toDouble();
    return (total - paid).clamp(0.0, double.infinity);
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
      setState(() => _errorMessage = 'Número inválido');
      return;
    }
    if (amount <= 0) {
      setState(() => _errorMessage = 'Debe ser mayor a 0');
      return;
    }
    if (_selectedOrderId != null) {
      final target = _pendingOrders.firstWhere(
        (o) => o['id'] == _selectedOrderId,
      );
      final pendingOfOrder = _pendingOf(target);
      if (amount > pendingOfOrder) {
        setState(
          () =>
              _errorMessage =
                  'Máx para este pedido: S/ ${pendingOfOrder.toStringAsFixed(2)}',
        );
        return;
      }
    } else {
      if (amount > widget.account.currentDebt) {
        setState(
          () =>
              _errorMessage =
                  'Supera la deuda total (S/ ${widget.account.currentDebt.toStringAsFixed(2)})',
        );
        return;
      }
    }
    setState(() => _errorMessage = null);
  }

  Future<void> _savePayment() async {
    if (_errorMessage != null || _amountCtrl.text.trim().isEmpty) return;
    if (_selectedAccount == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona una cuenta de destino',
        type: SnackbarType.warning,
      );
      return;
    }
    if (_selectedAccount!.type == 'CAJA' && _activeShift == null) {
      AppSnackbar.show(
        context,
        message:
            'La cuenta Caja no tiene un turno abierto. Abre el turno primero.',
        type: SnackbarType.error,
      );
      return;
    }

    final amount = double.parse(_amountCtrl.text.trim());
    setState(() => _isSaving = true);

    try {
      final adminProfileId = await _service.getAdminProfileId();
      if (!mounted) return;
      final config = context.read<AppConfigProvider>();
      final ratio = config.getDouble('points_to_soles_ratio', 0.01);
      final rate = config.getDouble('points_earning_rate', 0.03);

      await _service.registerPayment(
        account: widget.account,
        amount: amount,
        selectedAccount: _selectedAccount!,
        selectedOrderId: _selectedOrderId,
        notes:
            _notesCtrl.text.trim().isEmpty
                ? "Abono registrado desde Admin Credits"
                : _notesCtrl.text.trim(),
        pendingOrders: _pendingOrders,
        adminProfileId: adminProfileId,
        shiftId:
            _selectedAccount!.type == 'CAJA' && _activeShift != null
                ? _activeShift!['id'] as String?
                : null,
        pointsToSolesRatio: ratio,
        pointsEarningRate: rate,
      );

      if (mounted) {
        AppSnackbar.show(
          context,
          message:
              'Pago de S/ ${amount.toStringAsFixed(2)} registrado en ${_selectedAccount!.name}.',
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

  IconData _getIconForType(String type) {
    switch (type) {
      case 'CAJA':
        return Icons.point_of_sale_rounded;
      case 'BANCO':
        return Icons.account_balance_rounded;
      case 'DIGITAL':
        return Icons.smartphone_rounded;
      default:
        return Icons.wallet_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final debt = widget.account.currentDebt;
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

    final config = context.watch<AppConfigProvider>();
    final ratio = config.getDouble('points_to_soles_ratio', 0.01);
    final rate = config.getDouble('points_earning_rate', 0.03);

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
                        'Registrar abono / pago',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.account.partnerName,
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
              'Aplicar pago a',
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
                amount: null,
                isSelected: _selectedOrderId == null,
                onTap: () {
                  setState(() => _selectedOrderId = null);
                  _validarEntrada(_amountCtrl.text);
                },
              ),
              ..._pendingOrders.map((order) {
                final orderId = order['id'] as String;
                final shortId = orderId.substring(0, 8).toUpperCase();
                final pending = _pendingOf(order);
                final isParcial = order['payment_status'] == 'PARTIAL';

                final total = (order['total_amount'] as num).toDouble();
                int pointsEarned = 0;
                if (rate > 0 && ratio > 0) {
                  pointsEarned = (total * rate / ratio).floor();
                }

                return _OrderSelectionTile(
                  label: 'Pedido #$shortId',
                  sublabel:
                      isParcial
                          ? 'Pago parcial · Pendiente S/ ${pending.toStringAsFixed(2)}'
                          : 'Sin cobrar · S/ ${pending.toStringAsFixed(2)}',
                  amount: pending,
                  pointsEarned: pointsEarned,
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
                    color: AppColors.bg,
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
                          'No se encontraron pedidos a crédito pendientes. El pago se aplicará a la deuda general.',
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
                color: AppColors.bg,
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
              'Cuenta de destino',
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
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  itemCount: _accounts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final account = _accounts[index];
                    final isSelected = _selectedAccount?.id == account.id;
                    final typeColor =
                        account.type == 'CAJA'
                            ? AppColors.amber
                            : account.type == 'BANCO'
                            ? Colors.blue.shade600
                            : account.type == 'DIGITAL'
                            ? Colors.purple.shade500
                            : AppColors.textMuted;
                    return GestureDetector(
                      onTap: () => _onAccountChanged(account),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.teal : AppColors.bg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isSelected ? AppColors.teal : AppColors.border,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow:
                              isSelected
                                  ? [
                                    BoxShadow(
                                      color: AppColors.teal.withValues(
                                        alpha: 0.18,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                  : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _getIconForType(account.type),
                                  size: 13,
                                  color: isSelected ? Colors.white : typeColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  account.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? Colors.white.withValues(
                                              alpha: 0.2,
                                            )
                                            : typeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    account.type,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          isSelected
                                              ? Colors.white70
                                              : typeColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  'S/ ${account.balance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isSelected
                                            ? Colors.white70
                                            : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
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
                        'Esta caja no tiene un turno abierto. Abre el turno antes de registrar el cobro.',
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
            const SizedBox(height: 16),
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
                color: AppColors.bg,
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
                        'Confirmar pago',
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
}

class _OrderSelectionTile extends StatelessWidget {
  final String label;
  final String sublabel;
  final double? amount;
  final int? pointsEarned;
  final bool isSelected;
  final VoidCallback onTap;

  const _OrderSelectionTile({
    required this.label,
    required this.sublabel,
    this.amount,
    this.pointsEarned,
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
          color: isSelected ? AppColors.tealLight : AppColors.bg,
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
            if (pointsEarned != null && pointsEarned! > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      color: Colors.amber,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+$pointsEarned',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade800,
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
                  : AppColors.bg,
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
