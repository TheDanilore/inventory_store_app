import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class RegisterPaymentModal extends StatefulWidget {
  final VoidCallback onSaved;
  final CustomerCreditEntity account;
  final Future<void> Function(double amount, String method, String? notes)
  onSavePayment;

  const RegisterPaymentModal({
    super.key,
    required this.onSaved,
    required this.account,
    required this.onSavePayment,
  });

  static Future<bool?> show(
    BuildContext context, {
    required CustomerCreditEntity account,
    required VoidCallback onSaved,
    required Future<void> Function(double amount, String method, String? notes)
    onSavePayment,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (_) => RegisterPaymentModal(
              account: account,
              onSaved: onSaved,
              onSavePayment: onSavePayment,
            ),
      );
    } else {
      return showDialog<bool>(
        context: context,
        builder:
            (_) => RegisterPaymentModal(
              account: account,
              onSaved: onSaved,
              onSavePayment: onSavePayment,
            ),
      );
    }
  }

  @override
  State<RegisterPaymentModal> createState() => _RegisterPaymentModalState();
}

class _RegisterPaymentModalState extends State<RegisterPaymentModal> {
  final _supabase = Supabase.instance.client;
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _isSaving = false;
  bool _loadingOrders = true;
  bool _loadingAccounts = true;

  List<Map<String, dynamic>> _pendingOrders = [];
  String? _selectedOrderId;

  List<Map<String, dynamic>> _accounts = [];
  Map<String, dynamic>? _selectedAccount;
  Map<String, dynamic>? _activeShift;

  String? _errorMessage;
  String? _selectedQuickChip;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadPendingOrders(), _loadAccounts()]);
  }

  Future<void> _loadPendingOrders() async {
    try {
      final response = await _supabase
          .from('orders')
          .select('id, total_amount, amount_paid, payment_status, created_at')
          .eq('customer_id', widget.account.profileId)
          .inFilter('payment_status', ['PENDING', 'PARTIAL'])
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _pendingOrders = List<Map<String, dynamic>>.from(response);
          _loadingOrders = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  Future<void> _loadAccounts() async {
    try {
      final response = await _supabase
          .from('financial_accounts')
          .select('id, name, type, balance')
          .eq('is_active', true)
          .order('name');

      if (mounted) {
        final list = List<Map<String, dynamic>>.from(response);
        setState(() {
          _accounts = list;
          if (list.isNotEmpty) {
            _selectedAccount = list.first;
          }
          _loadingAccounts = false;
        });

        if (_selectedAccount != null && _selectedAccount!['type'] == 'CAJA') {
          await _checkActiveShift(_selectedAccount!['id'] as String);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  Future<void> _checkActiveShift(String accountId) async {
    try {
      final response =
          await _supabase
              .from('cash_shifts')
              .select('id, status')
              .eq('account_id', accountId)
              .eq('status', 'OPEN')
              .maybeSingle();

      if (mounted) {
        setState(() => _activeShift = response);
      }
    } catch (_) {
      if (mounted) setState(() => _activeShift = null);
    }
  }

  Future<void> _onAccountChanged(Map<String, dynamic> account) async {
    setState(() {
      _selectedAccount = account;
      _activeShift = null;
    });
    if (account['type'] == 'CAJA') {
      await _checkActiveShift(account['id'] as String);
    }
  }

  double _pendingOf(Map<String, dynamic> order) {
    final total = (order['total_amount'] as num).toDouble();
    final paid = (order['amount_paid'] as num).toDouble();
    return (total - paid).clamp(0.0, double.infinity);
  }

  void _validateAmount(String value, {bool fromQuick = false}) {
    if (!fromQuick && _selectedQuickChip != null) {
      setState(() => _selectedQuickChip = null);
    }

    if (value.trim().isEmpty) {
      setState(() => _errorMessage = null);
      return;
    }

    final amount = double.tryParse(value.trim());
    if (amount == null) {
      setState(() => _errorMessage = 'Ingrese un monto válido');
      return;
    }

    if (amount <= 0) {
      setState(() => _errorMessage = 'El monto debe ser mayor a 0');
      return;
    }

    if (_selectedOrderId != null) {
      final target = _pendingOrders.firstWhere(
        (o) => o['id'] == _selectedOrderId,
        orElse: () => {},
      );
      if (target.isNotEmpty) {
        final pending = _pendingOf(target);
        if (amount > pending) {
          setState(
            () =>
                _errorMessage =
                    'Máximo para este pedido: S/ ${pending.toStringAsFixed(2)}',
          );
          return;
        }
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

  void _selectQuickAmount(double amount, String chipId) {
    setState(() {
      _selectedQuickChip = chipId;
      _amountCtrl.text = amount.toStringAsFixed(2);
    });
    _validateAmount(_amountCtrl.text, fromQuick: true);
  }

  Future<void> _executePaymentInSupabase({
    required double amount,
    required String notes,
  }) async {
    // 1. Intentar llamar a la función RPC atómica de Supabase (1 sola llamada HTTP)
    try {
      await _supabase.rpc(
        'register_credit_payment_rpc',
        params: {
          'p_customer_id': widget.account.profileId,
          'p_credit_id':
              widget.account.id.isNotEmpty ? widget.account.id : null,
          'p_amount': amount,
          'p_account_id':
              _selectedAccount != null ? _selectedAccount!['id'] : null,
          'p_order_id': _selectedOrderId,
          'p_notes': notes,
          'p_shift_id': _activeShift != null ? _activeShift!['id'] : null,
        },
      );
      return;
    } catch (_) {
      // Fallback imperativo en caso la función RPC no exista aún en el entorno
    }

    // 2. Determinar órdenes a las que se aplicará el pago (Fallback)
    final ordersToApply =
        _selectedOrderId != null
            ? _pendingOrders.where((o) => o['id'] == _selectedOrderId).toList()
            : List<Map<String, dynamic>>.from(_pendingOrders);

    double remaining = amount;
    for (final order in ordersToApply) {
      if (remaining <= 0) break;
      final orderId = order['id'] as String;
      final total = (order['total_amount'] as num).toDouble();
      final alreadyPaid = (order['amount_paid'] as num).toDouble();
      final pendingOfOrder = (total - alreadyPaid).clamp(0.0, double.infinity);
      final toApply = remaining >= pendingOfOrder ? pendingOfOrder : remaining;
      final newAmountPaid = alreadyPaid + toApply;
      remaining -= toApply;

      final newPaymentStatus = newAmountPaid >= total ? 'PAID' : 'PARTIAL';

      int pointsEarned = 0;
      if (newPaymentStatus == 'PAID') {
        pointsEarned = (total * 0.03 / 0.01).floor();
      }

      await _supabase
          .from('orders')
          .update({
            'amount_paid': newAmountPaid,
            'payment_status': newPaymentStatus,
            if (pointsEarned > 0) 'points_earned': pointsEarned,
          })
          .eq('id', orderId);

      // Insertar movimiento en customer_credit_movements
      if (toApply > 0) {
        final creditId = widget.account.id;
        final methodLabel =
            _selectedAccount != null
                ? _selectedAccount!['name'] as String
                : 'EFECTIVO';

        if (creditId.isNotEmpty) {
          try {
            await _supabase.from('customer_credit_movements').insert({
              'customer_credit_id': creditId,
              'order_id': orderId,
              'movement_type': 'PAYMENT',
              'amount': toApply,
              'payment_method': methodLabel,
              'notes': notes,
            });
          } catch (_) {}
        }

        // Insertar movimiento financiero
        if (_selectedAccount != null) {
          try {
            await _supabase.from('account_movements').insert({
              'account_id': _selectedAccount!['id'],
              'movement_type': 'INCOME',
              'amount': toApply,
              'description':
                  'Cobro de crédito — Pedido #${orderId.length >= 8 ? orderId.substring(0, 8).toUpperCase() : orderId}',
              'reference_type': 'orders',
              'reference_id': orderId,
              if (_activeShift != null) 'shift_id': _activeShift!['id'],
            });
          } catch (_) {}
        }
      }

      // Sumar puntos al cliente si el pedido quedó pagado
      if (pointsEarned > 0) {
        try {
          final profileResp =
              await _supabase
                  .from('profiles')
                  .select('wallet_balance')
                  .eq('id', widget.account.profileId)
                  .maybeSingle();
          final currentWallet =
              (profileResp?['wallet_balance'] as num?)?.toInt() ?? 0;

          await _supabase
              .from('profiles')
              .update({'wallet_balance': currentWallet + pointsEarned})
              .eq('id', widget.account.profileId);

          await _supabase.from('wallet_movements').insert({
            'profile_id': widget.account.profileId,
            'order_id': orderId,
            'points': pointsEarned,
            'movement_type': 'EARNED',
            'description': 'Monedas ganadas al saldar pedido a crédito',
          });
        } catch (_) {}
      }
    }

    // 2. Actualizar la deuda total en customer_credits
    try {
      final creditResp =
          await _supabase
              .from('customer_credits')
              .select('current_debt, id')
              .eq('profile_id', widget.account.profileId)
              .maybeSingle();

      if (creditResp != null) {
        final currentDebt = (creditResp['current_debt'] as num).toDouble();
        final newDebt = (currentDebt - amount).clamp(0.0, double.infinity);
        await _supabase
            .from('customer_credits')
            .update({'current_debt': newDebt})
            .eq('id', creditResp['id']);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    final debt = widget.account.currentDebt;
    if (debt <= 0) {
      AppSnackbar.showMessenger(
        ScaffoldMessenger.of(context),
        message: 'El cliente no tiene deuda pendiente para abonar.',
        type: SnackbarType.error,
      );
      return;
    }

    if (_selectedAccount != null &&
        _selectedAccount!['type'] == 'CAJA' &&
        _activeShift == null) {
      AppSnackbar.showMessenger(
        ScaffoldMessenger.of(context),
        message: 'La cuenta Caja seleccionada no tiene un turno abierto.',
        type: SnackbarType.error,
      );
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Ingrese un monto válido.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final notesText =
          _notesCtrl.text.trim().isEmpty
              ? 'Abono registrado a crédito'
              : _notesCtrl.text.trim();

      await _executePaymentInSupabase(amount: amount, notes: notesText);

      final methodLabel =
          _selectedAccount != null
              ? _selectedAccount!['name'] as String
              : 'EFECTIVO';

      try {
        await widget.onSavePayment(amount, methodLabel, notesText);
      } catch (_) {}

      if (mounted) {
        widget.onSaved();
        Navigator.pop(context, true);
        AppSnackbar.showMessenger(
          ScaffoldMessenger.of(context),
          message:
              'Pago de S/ ${amount.toStringAsFixed(2)} registrado correctamente.',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showMessenger(
          ScaffoldMessenger.of(context),
          message: 'Error al registrar el pago: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
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
    final mediaQuery = MediaQuery.of(context);
    final isMobile = mediaQuery.size.width < 600;
    final bottomInset = mediaQuery.viewInsets.bottom;
    final debt = widget.account.currentDebt;
    final hasDebt = debt > 0;
    final bool cajaSinTurno =
        _selectedAccount != null &&
        _selectedAccount!['type'] == 'CAJA' &&
        _activeShift == null;

    final isSubmitDisabled =
        _isSaving ||
        !hasDebt ||
        cajaSinTurno ||
        _errorMessage != null ||
        _amountCtrl.text.trim().isEmpty;

    final childContent = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        isMobile ? 12 : 24,
        24,
        24 + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isMobile) ...[
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
          ],
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(12),
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
                      'Registrar Abono / Pago',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Selecciona el modo de aplicación y la cuenta de destino',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                icon: const Icon(
                  Icons.close_rounded,
                  color: AppColors.textMuted,
                ),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Tarjeta Deuda Actual
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: hasDebt ? AppColors.dangerLight : AppColors.successLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: (hasDebt ? AppColors.danger : AppColors.success)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      hasDebt
                          ? Icons.account_balance_wallet_rounded
                          : Icons.check_circle_rounded,
                      color: hasDebt ? AppColors.danger : AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      hasDebt ? 'Deuda actual:' : 'Deuda saldada:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: hasDebt ? AppColors.danger : AppColors.success,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                Text(
                  'S/ ${debt.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                    color: hasDebt ? AppColors.danger : AppColors.success,
                  ),
                ),
              ],
            ),
          ),

          if (hasDebt) ...[
            const SizedBox(height: 16),
            const Text(
              'Aplicar pago a:',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),

            if (_loadingOrders)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else ...[
              // Opción FIFO
              _OrderSelectionTile(
                label: 'Distribuir automáticamente (FIFO)',
                sublabel: 'Salda los pedidos más antiguos primero',
                isSelected: _selectedOrderId == null,
                onTap: () {
                  setState(() => _selectedOrderId = null);
                  _validateAmount(_amountCtrl.text);
                },
              ),

              // Pedidos pendientes específicos
              ..._pendingOrders.map((order) {
                final orderId = order['id'] as String;
                final shortId =
                    orderId.length >= 8
                        ? orderId.substring(0, 8).toUpperCase()
                        : orderId;
                final pending = _pendingOf(order);
                final isPartial = order['payment_status'] == 'PARTIAL';
                final total = (order['total_amount'] as num).toDouble();
                final pointsEarned = (total * 0.03 / 0.01).floor();

                return _OrderSelectionTile(
                  label: 'Pedido #$shortId',
                  sublabel:
                      isPartial
                          ? 'Pago parcial · Pendiente S/ ${pending.toStringAsFixed(2)}'
                          : 'Sin cobrar · S/ ${pending.toStringAsFixed(2)}',
                  pointsEarned: pointsEarned > 0 ? pointsEarned : null,
                  isSelected: _selectedOrderId == orderId,
                  onTap: () {
                    setState(() {
                      _selectedOrderId = orderId;
                      _amountCtrl.text = pending.toStringAsFixed(2);
                    });
                    _validateAmount(_amountCtrl.text);
                  },
                );
              }),
            ],

            const SizedBox(height: 16),
            // Chips de Montos Rápidos
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickAmountChip(
                  label: 'Deuda Total (S/ ${debt.toStringAsFixed(2)})',
                  isSelected: _selectedQuickChip == 'TOTAL',
                  onTap: () => _selectQuickAmount(debt, 'TOTAL'),
                ),
                if (debt >= 20)
                  _QuickAmountChip(
                    label: '50% (S/ ${(debt / 2).toStringAsFixed(2)})',
                    isSelected: _selectedQuickChip == '50%',
                    onTap: () => _selectQuickAmount(debt / 2, '50%'),
                  ),
              ],
            ),

            const SizedBox(height: 16),
            // Campo Monto
            const Text(
              'Monto a abonar (S/)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: _validateAmount,
              decoration: InputDecoration(
                hintText: '0.00',
                prefixIcon: const Icon(
                  Icons.attach_money_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _errorMessage!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Cuenta de Destino
            const Text(
              'Cuenta de destino (Caja / Banco)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            if (_loadingAccounts)
              const SizedBox(
                height: 40,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.surface,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>>(
                    value: _selectedAccount,
                    isExpanded: true,
                    items:
                        _accounts.map((acc) {
                          final type = acc['type'] as String? ?? '';
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: acc,
                            child: Row(
                              children: [
                                Icon(
                                  _getIconForType(type),
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  acc['name'] as String? ?? 'Cuenta',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                    onChanged: (val) {
                      if (val != null) _onAccountChanged(val);
                    },
                  ),
                ),
              ),

            // Alerta de Turno Abierto o Cerrado
            if (_selectedAccount != null &&
                _selectedAccount!['type'] == 'CAJA') ...[
              const SizedBox(height: 8),
              if (_activeShift != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: AppColors.success,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Turno abierto · Se registrará en la caja activa',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
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
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: AppColors.danger,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'La cuenta Caja no tiene un turno abierto. Abre el turno primero.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],

            const SizedBox(height: 16),
            // Notas Opcionales
            const Text(
              'Notas / Referencia (opcional)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ej. Pago del pedido #123, depósito bcp...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],

          const SizedBox(height: 24),
          // Acciones
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isSaving ? null : () => Navigator.pop(context),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: isSubmitDisabled ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  disabledBackgroundColor: Colors.grey.shade300,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isSaving
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Confirmar pago',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
              ),
            ],
          ),
        ],
      ),
    );

    if (isMobile) {
      return Container(
        constraints: BoxConstraints(maxHeight: mediaQuery.size.height * 0.88),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: childContent,
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: SizedBox(width: 500, child: childContent),
    );
  }
}

class _OrderSelectionTile extends StatelessWidget {
  final String label;
  final String sublabel;
  final int? pointsEarned;
  final bool isSelected;
  final VoidCallback onTap;

  const _OrderSelectionTile({
    required this.label,
    required this.sublabel,
    this.pointsEarned,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppColors.primary : AppColors.textMuted,
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
                              ? AppColors.primary
                              : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          isSelected ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (pointsEarned != null && pointsEarned! > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                      '+$pointsEarned pts',
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
  final VoidCallback onTap;

  const _QuickAmountChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.success : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.success : AppColors.border,
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
