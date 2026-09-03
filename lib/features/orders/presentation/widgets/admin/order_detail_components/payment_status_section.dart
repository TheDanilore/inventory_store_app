import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/order_detail/order_detail_cubit.dart';
import 'package:inventory_store_app/features/orders/presentation/widgets/admin/order_detail_components/order_detail_section_card.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';

class PaymentStatusSection extends StatefulWidget {
  final String paymentStatus;
  final double totalAmount;
  final double amountPaid;
  final String paymentMethod;
  final Map<String, dynamic>? creditInfo;
  final String orderId;
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
  String? _selectedQuickAmount;

  // Cuenta financiera seleccionada para el abono
  Map<String, dynamic>? _selectedAccount;
  // Turno activo (solo para CAJA)
  Map<String, dynamic>? _activeShift;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _abonoCtrl.addListener(_onAbonoChanged);
    if (widget.accounts.isNotEmpty) {
      _selectedAccount = widget.accounts.first;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCashShift();
    });
  }

  void _onAbonoChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkCashShift() async {
    if (!mounted) return;
    if (_selectedAccount != null && _selectedAccount!['type'] == 'CAJA') {
      final shiftId =
          await context.read<OrderDetailCubit>().getActiveCashShift();
      if (mounted) {
        setState(() {
          _activeShift = shiftId != null ? {'id': shiftId} : null;
        });
      }
    } else {
      if (_activeShift != null && mounted) {
        setState(() => _activeShift = null);
      }
    }
  }

  @override
  void dispose() {
    _abonoCtrl.removeListener(_onAbonoChanged);
    _abonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _onAccountTap(Map<String, dynamic> account) async {
    setState(() {
      _selectedAccount = account;
    });
    await _checkCashShift();
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
      _selectedQuickAmount = null;
    }
    if (mounted) setState(() {});
  }

  Future<void> _registrarAbono() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedAccount == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona una cuenta de destino',
        type: SnackbarType.warning,
      );
      return;
    }

    final amount = double.parse(_abonoCtrl.text.trim());
    setState(() => _isRegistering = true);

    try {
      final cubit = context.read<OrderDetailCubit>();

      // Validar turno de caja si es necesario
      String? shiftId;
      if (_selectedAccount!['type'] == 'CAJA') {
        shiftId = await cubit.getActiveCashShift();
        if (shiftId == null && mounted) {
          AppSnackbar.show(
            context,
            message:
                'La caja no tiene un turno abierto. Abre el turno primero.',
            type: SnackbarType.error,
          );
          setState(() => _isRegistering = false);
          return;
        }
      }

      final success = await cubit.registerPayment(
        customerId: widget.customerId,
        creditId: widget.creditInfo?['id'],
        amount: amount,
        accountId: _selectedAccount!['id'],
        orderId: widget.orderId,
        notes: 'Abono registrado desde detalle de pedido',
        shiftId: shiftId,
      );

      if (mounted) {
        if (success) {
          _abonoCtrl.clear();
          setState(() => _selectedQuickAmount = null);
          AppSnackbar.show(
            context,
            message:
                'Abono de S/ ${amount.toStringAsFixed(2)} registrado con éxito.',
            type: SnackbarType.success,
          );
          widget.onPaymentRegistered();
        } else {
          AppSnackbar.show(
            context,
            message: cubit.state.errorMessage ?? 'Error al registrar abono.',
            type: SnackbarType.error,
          );
        }
      }
    } catch (e, st) {
      LoggerService.e(
        'Excepción al registrar abono en orden ${widget.orderId}',
        tag: 'PAYMENT_STATUS_SECTION',
        error: e,
        stackTrace: st,
      );
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Excepción al registrar abono: $e',
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

    final amountParsed = double.tryParse(_abonoCtrl.text.trim()) ?? 0.0;
    final bool isAmountValid =
        amountParsed > 0 && amountParsed <= (pendingAmount + 0.001);

    final bool isButtonEnabled =
        !_isRegistering &&
        isAmountValid &&
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

          // Sección de abono (crédito con saldo pendiente)
          if (widget.paymentMethod == 'CRÉDITO' && pendingAmount > 0) ...[
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
                      _formKey.currentState?.validate();
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
                      _formKey.currentState?.validate();
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
                      _formKey.currentState?.validate();
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
                    _formKey.currentState?.validate();
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Campo de monto ─────────────────────────────────────────
            Form(
              key: _formKey,
              child: TextFormField(
                controller: _abonoCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                onChanged: (v) {
                  _validarEntrada(v);
                  if (_formKey.currentState != null) {
                    _formKey.currentState!.validate();
                  }
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Requerido';
                  }
                  final amount = double.tryParse(value.trim());
                  final pendingOrderAmount =
                      widget.totalAmount - widget.amountPaid;
                  if (amount == null) return 'Número inválido';
                  if (amount <= 0) return 'Debe ser mayor a 0';
                  if (amount > pendingOrderAmount) {
                    return 'Máx: S/ ${pendingOrderAmount.toStringAsFixed(2)}';
                  }
                  return null;
                },
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: 'Monto a abonar (S/)',
                  hintStyle: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 13,
                  ),
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(left: 14, right: 8),
                    child: Text(
                      'S/',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.teal,
                      ),
                    ),
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
