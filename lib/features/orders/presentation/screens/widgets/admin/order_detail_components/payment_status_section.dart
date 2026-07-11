import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/features/orders/presentation/screens/widgets/admin/order_detail_components/order_detail_section_card.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentStatusSection extends StatefulWidget {
  final String paymentStatus;
  final double totalAmount;
  final double amountPaid;
  final String paymentMethod;
  final Map<String, dynamic>? creditInfo;
  final String orderId;
  final SupabaseClient supabase;
  final List<Map<String, dynamic>> accounts; // cuentas financieras ordenadas
  final String? customerId;
  final int pointsEarned;
  final VoidCallback onPaymentRegistered;
  final bool isLoyaltyEnabled;

  const PaymentStatusSection({
    super.key,
    required this.paymentStatus,
    required this.totalAmount,
    required this.amountPaid,
    required this.paymentMethod,
    required this.creditInfo,
    required this.orderId,
    required this.supabase,
    required this.accounts,
    required this.customerId,
    required this.pointsEarned,
    required this.onPaymentRegistered,
    required this.isLoyaltyEnabled,
  });

  @override
  State<PaymentStatusSection> createState() => _PaymentStatusSectionState();
}

class _PaymentStatusSectionState extends State<PaymentStatusSection> {
  bool _isRegistering = false;
  final _abonoCtrl = TextEditingController();
  String? _errorMessage;
  String? _selectedQuickAmount;

  // Cuenta financiera seleccionada para el abono
  Map<String, dynamic>? _selectedAccount;
  // Turno activo (solo para CAJA)
  Map<String, dynamic>? _activeShift;

  @override
  void initState() {
    super.initState();
    // Preseleccionar la primera cuenta disponible
    if (widget.accounts.isNotEmpty) {
      _selectedAccount = widget.accounts.first;
      if (_selectedAccount!['type'] == 'CAJA') {
        _checkActiveShift(_selectedAccount!['id'] as String);
      }
    }
  }

  @override
  void dispose() {
    _abonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkActiveShift(String accountId) async {
    try {
      final resp =
          await widget.supabase
              .from('cash_shifts')
              .select('id, opened_at')
              .eq('account_id', accountId)
              .eq('status', 'OPEN')
              .maybeSingle();
      if (mounted) setState(() => _activeShift = resp);
    } catch (_) {
      if (mounted) setState(() => _activeShift = null);
    }
  }

  Future<void> _onAccountTap(Map<String, dynamic> account) async {
    setState(() {
      _selectedAccount = account;
      _activeShift = null;
    });
    if (account['type'] == 'CAJA') {
      await _checkActiveShift(account['id'] as String);
    }
  }

  IconData _iconForType(String type) {
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

  Color _colorForType(String type) {
    switch (type) {
      case 'CAJA':
        return const Color(0xFFF59E0B);
      case 'BANCO':
        return const Color(0xFF2563EB);
      case 'DIGITAL':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF6B7280);
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
    final pendingOrderAmount = widget.totalAmount - widget.amountPaid;
    if (amount == null) {
      setState(() => _errorMessage = 'Número inválido');
    } else if (amount <= 0) {
      setState(() => _errorMessage = 'Debe ser mayor a 0');
    } else if (amount > pendingOrderAmount) {
      setState(
        () =>
            _errorMessage = 'Máx: S/ ${pendingOrderAmount.toStringAsFixed(2)}',
      );
    } else {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _registrarAbono() async {
    if (_errorMessage != null || _abonoCtrl.text.trim().isEmpty) return;
    if (_selectedAccount == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona una cuenta de destino',
        type: SnackbarType.warning,
      );
      return;
    }
    final isCaja = _selectedAccount!['type'] == 'CAJA';
    if (isCaja && _activeShift == null) {
      AppSnackbar.show(
        context,
        message: 'La caja no tiene un turno abierto. Abre el turno primero.',
        type: SnackbarType.error,
      );
      return;
    }

    final amount = double.parse(_abonoCtrl.text.trim());
    setState(() => _isRegistering = true);

    try {
      final authUserId = widget.supabase.auth.currentUser?.id;
      String? adminProfileId;
      if (authUserId != null) {
        final p =
            await widget.supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', authUserId)
                .maybeSingle();
        adminProfileId = p?['id'] as String?;
      }

      final creditId = widget.creditInfo!['id'] as String;
      final currentDebt =
          (widget.creditInfo!['current_debt'] as num).toDouble();
      final newGeneralDebt = (currentDebt - amount).clamp(0.0, currentDebt);

      // 1. Actualizar deuda en customer_credits
      await widget.supabase
          .from('customer_credits')
          .update({
            'current_debt': newGeneralDebt,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', creditId);

      // 2. Registrar en customer_credit_movements con el nombre de la cuenta como payment_method
      await widget.supabase.from('customer_credit_movements').insert({
        'customer_credit_id': creditId,
        'order_id': widget.orderId,
        'movement_type': 'PAYMENT',
        'amount': amount,
        'payment_method': _selectedAccount!['name'] as String,
        'notes': 'Abono registrado desde detalle de pedido',
        if (adminProfileId != null) 'created_by': adminProfileId,
      });

      // 3. Actualizar orders.amount_paid y payment_status
      final newOrderAmountPaid = widget.amountPaid + amount;
      final newPaymentStatus =
          newOrderAmountPaid >= widget.totalAmount ? 'PAID' : 'PARTIAL';
      await widget.supabase
          .from('orders')
          .update({
            'payment_status': newPaymentStatus,
            'amount_paid': newOrderAmountPaid,
          })
          .eq('id', widget.orderId);

      // 3.5 Otorgar monedas si el pedido a crédito fue pagado completamente
      if (widget.isLoyaltyEnabled &&
          newPaymentStatus == 'PAID' &&
          widget.paymentMethod == 'CRÉDITO' &&
          widget.customerId != null &&
          widget.pointsEarned > 0) {
        final earnedExists =
            await widget.supabase
                .from('wallet_movements')
                .select('id')
                .eq('order_id', widget.orderId)
                .eq('movement_type', 'EARNED')
                .maybeSingle();

        if (earnedExists == null) {
          final profileData =
              await widget.supabase
                  .from('profiles')
                  .select('wallet_balance')
                  .eq('id', widget.customerId!)
                  .maybeSingle();

          if (profileData != null) {
            final curBal =
                (profileData['wallet_balance'] as num?)?.toInt() ?? 0;
            await Future.wait([
              widget.supabase
                  .from('profiles')
                  .update({'wallet_balance': curBal + widget.pointsEarned})
                  .eq('id', widget.customerId!),
              widget.supabase.from('wallet_movements').insert({
                'profile_id': widget.customerId!,
                'order_id': widget.orderId,
                'points': widget.pointsEarned,
                'movement_type': 'EARNED',
                'description':
                    'Monedas obtenidas al pagar crédito de pedido #${widget.orderId}',
              }),
            ]);
          }
        }
      }

      // 4. Registrar INGRESO en account_movements
      final shiftId =
          isCaja && _activeShift != null
              ? _activeShift!['id'] as String?
              : null;
      await widget.supabase.from('account_movements').insert({
        'account_id': _selectedAccount!['id'],
        'movement_type': 'INCOME',
        'amount': amount,
        'description': 'Cobro de crédito — Pedido #${widget.orderId}',
        'reference_type': 'orders',
        'reference_id': widget.orderId,
        if (shiftId != null) 'shift_id': shiftId,
        if (adminProfileId != null) 'created_by': adminProfileId,
      });

      // 5. Actualizar saldo de la cuenta financiera
      final currentBalance =
          ((_selectedAccount!['balance'] as num?)?.toDouble() ?? 0.0);
      await widget.supabase
          .from('financial_accounts')
          .update({'balance': currentBalance + amount})
          .eq('id', _selectedAccount!['id'] as String);

      if (mounted) {
        AppSnackbar.show(
          context,
          message:
              'Abono de S/ ${amount.toStringAsFixed(2)} registrado en ${_selectedAccount!['name']}.',
          type: SnackbarType.success,
        );
        widget.onPaymentRegistered();
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al registrar abono: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingAmount = widget.totalAmount - widget.amountPaid;
    Color badgeColor;
    String badgeLabel;
    switch (widget.paymentStatus) {
      case 'PAID':
        badgeColor = Colors.teal;
        badgeLabel = 'Pagado completo';
        break;
      case 'PARTIAL':
        badgeColor = Colors.amber.shade700;
        badgeLabel = 'Pago parcial';
        break;
      case 'PENDING':
      default:
        badgeColor = Colors.deepOrange;
        badgeLabel = 'Pendiente de pago';
    }

    final bool cajaSinTurno =
        _selectedAccount != null &&
        _selectedAccount!['type'] == 'CAJA' &&
        _activeShift == null;

    final bool isButtonEnabled =
        !_isRegistering &&
        _abonoCtrl.text.trim().isNotEmpty &&
        _errorMessage == null &&
        _selectedAccount != null &&
        !cajaSinTurno;

    return OrderDetailSectionCard(
      title: 'Estado de Pago',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge de estado
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Fila de totales
          Row(
            children: [
              Expanded(
                child: _PStatRow(
                  label: 'Total',
                  value: 'S/ ${widget.totalAmount.toStringAsFixed(2)}',
                ),
              ),
              Expanded(
                child: _PStatRow(
                  label: 'Pagado',
                  value: 'S/ ${widget.amountPaid.toStringAsFixed(2)}',
                  valueColor: Colors.teal,
                ),
              ),
              if (widget.paymentStatus != 'PAID')
                Expanded(
                  child: _PStatRow(
                    label: 'Pendiente',
                    value: 'S/ ${pendingAmount.toStringAsFixed(2)}',
                    valueColor: Colors.deepOrange,
                    bold: true,
                  ),
                ),
            ],
          ),

          // Sección de abono (solo crédito pendiente)
          if (widget.paymentMethod == 'CRÉDITO' &&
              pendingAmount > 0 &&
              widget.creditInfo != null) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            const Text(
              'Registrar abono',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),

            // ── Montos rápidos ─────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (pendingAmount >= 50)
                  _AbonoQuickChip(
                    label: 'S/ 50',
                    isSelected: _selectedQuickAmount == '50.00',
                    onTap: () {
                      setState(() => _selectedQuickAmount = '50.00');
                      _abonoCtrl.text = '50.00';
                      _validarEntrada('50.00', fromQuick: true);
                    },
                  ),
                if (pendingAmount >= 100)
                  _AbonoQuickChip(
                    label: 'S/ 100',
                    isSelected: _selectedQuickAmount == '100.00',
                    onTap: () {
                      setState(() => _selectedQuickAmount = '100.00');
                      _abonoCtrl.text = '100.00';
                      _validarEntrada('100.00', fromQuick: true);
                    },
                  ),
                if (pendingAmount >= 200)
                  _AbonoQuickChip(
                    label: 'S/ 200',
                    isSelected: _selectedQuickAmount == '200.00',
                    onTap: () {
                      setState(() => _selectedQuickAmount = '200.00');
                      _abonoCtrl.text = '200.00';
                      _validarEntrada('200.00', fromQuick: true);
                    },
                  ),
                _AbonoQuickChip(
                  label: 'Total (S/ ${pendingAmount.toStringAsFixed(2)})',
                  isSelected:
                      _selectedQuickAmount == pendingAmount.toStringAsFixed(2),
                  isTotal: true,
                  onTap: () {
                    final v = pendingAmount.toStringAsFixed(2);
                    setState(() => _selectedQuickAmount = v);
                    _abonoCtrl.text = v;
                    _validarEntrada(v, fromQuick: true);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Campo de monto ─────────────────────────────────────────
            TextField(
              controller: _abonoCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              onChanged: _validarEntrada,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Monto a abonar (S/)',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                errorText: _errorMessage,
                errorMaxLines: 2,
                prefixIcon: Icon(
                  Icons.attach_money_rounded,
                  color:
                      _errorMessage != null
                          ? Colors.deepOrange
                          : Colors.grey.shade500,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                isDense: true,
              ),
            ),
            const SizedBox(height: 14),

            // ── Selector de cuenta destino (scroll horizontal) ─────────
            const Text(
              'Cuenta de destino',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.accounts.isEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_rounded, size: 13, color: Colors.red),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'No hay cuentas activas.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red,
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
                  itemCount: widget.accounts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final acc = widget.accounts[index];
                    final isSelected = _selectedAccount?['id'] == acc['id'];
                    final type = acc['type'] as String? ?? 'OTRO';
                    final typeColor = _colorForType(type);
                    final balance = (acc['balance'] as num?)?.toDouble() ?? 0.0;
                    return GestureDetector(
                      onTap: () => _onAccountTap(acc),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.teal : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isSelected ? Colors.teal : Colors.grey.shade300,
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow:
                              isSelected
                                  ? [
                                    BoxShadow(
                                      color: Colors.teal.withValues(
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
                                  _iconForType(type),
                                  size: 13,
                                  color: isSelected ? Colors.white : typeColor,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  acc['name'] as String,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isSelected
                                            ? Colors.white
                                            : Colors.black87,
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
                                    type,
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
                                  'S/ ${balance.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isSelected
                                            ? Colors.white70
                                            : Colors.grey.shade500,
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

            // Advertencia CAJA sin turno
            if (cajaSinTurno) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_rounded, size: 13, color: Colors.red),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Esta caja no tiene turno abierto. Abre el turno antes de registrar el abono.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Info turno activo
            if (_selectedAccount != null &&
                _selectedAccount!['type'] == 'CAJA' &&
                _activeShift != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.teal.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: Colors.teal,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Turno abierto · Se registrará en el turno activo',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.teal,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Botón Abonar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  disabledForegroundColor: Colors.grey.shade500,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onPressed: isButtonEnabled ? _registrarAbono : null,
                icon:
                    _isRegistering
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  _isRegistering
                      ? 'Registrando...'
                      : _selectedAccount != null
                      ? 'Abonar a ${_selectedAccount!['name']}'
                      : 'Abonar',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Chip de monto rápido para la sección de abono
class _AbonoQuickChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isTotal;
  final VoidCallback onTap;

  const _AbonoQuickChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color bgColor;
    final Color borderColor;
    final Color textColor;

    if (isSelected) {
      bgColor = isTotal ? Colors.teal : Colors.teal;
      borderColor = Colors.teal;
      textColor = Colors.white;
    } else if (isTotal) {
      bgColor = Colors.teal.withValues(alpha: 0.07);
      borderColor = Colors.teal.withValues(alpha: 0.4);
      textColor = Colors.teal.shade700;
    } else {
      bgColor = Colors.grey.shade50;
      borderColor = Colors.grey.shade300;
      textColor = Colors.grey.shade600;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: Colors.teal.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_rounded, size: 11, color: textColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PStatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool bold;
  const _PStatRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.bold = false,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}
