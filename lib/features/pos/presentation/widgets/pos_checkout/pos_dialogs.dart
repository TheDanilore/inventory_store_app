import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

class PosConfirmationDialog extends StatefulWidget {
  final double totalFinal;
  final String? clienteName;
  final String paymentMethod;
  final VoidCallback? onConfirm;

  const PosConfirmationDialog({
    super.key,
    required this.totalFinal,
    this.clienteName,
    required this.paymentMethod,
    this.onConfirm,
  });

  @override
  State<PosConfirmationDialog> createState() => _PosConfirmationDialogState();
}

class _PosConfirmationDialogState extends State<PosConfirmationDialog> {
  late TextEditingController _receivedCtrl;
  double _montoRecibido = 0.0;

  bool get _isCashPayment {
    final method = widget.paymentMethod.toUpperCase();
    return method.contains('EFECTIVO') || method.contains('CAJA');
  }

  @override
  void initState() {
    super.initState();
    _montoRecibido = widget.totalFinal;
    _receivedCtrl = TextEditingController(
      text: widget.totalFinal.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _receivedCtrl.dispose();
    super.dispose();
  }

  void _onReceivedChanged(String text) {
    final parsed = double.tryParse(text) ?? 0.0;
    setState(() => _montoRecibido = parsed);
  }

  void _setPresetAmount(double amount) {
    _receivedCtrl.text = amount.toStringAsFixed(2);
    setState(() => _montoRecibido = amount);
  }

  void _confirm() {
    Navigator.pop(context, true);
    widget.onConfirm?.call();
  }

  @override
  Widget build(BuildContext context) {
    final vuelto = _montoRecibido - widget.totalFinal;
    final faltaDinero = _isCashPayment && vuelto < -0.01;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!faltaDinero) _confirm();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          Navigator.pop(context, false);
        },
      },
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  color: AppColors.teal,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Confirmar Venta',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Verifica los datos antes de procesar',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),

                  // Resumen de cliente y método
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: [
                        _RowItem(
                          label: 'Cliente',
                          value: widget.clienteName ?? 'Público General',
                          icon: Icons.person_outline_rounded,
                        ),
                        const SizedBox(height: 8),
                        _RowItem(
                          label: 'Método de pago',
                          value: widget.paymentMethod,
                          icon: Icons.payment_rounded,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Caja destacada de Total
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.teal.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'TOTAL A COBRAR',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: AppColors.tealDark,
                          ),
                        ),
                        Text(
                          'S/ ${widget.totalFinal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.tealDark,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Calculadora de Vuelto en Efectivo
                  if (_isCashPayment) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'PAGO EN EFECTIVO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _receivedCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      onChanged: _onReceivedChanged,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      decoration: InputDecoration(
                        prefixText: 'S/ ',
                        prefixStyle: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                        labelText: 'Monto recibido',
                        labelStyle: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.teal,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Botones de denominaciones rápidas
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _PresetChip(
                          label: 'Exacto',
                          onTap: () => _setPresetAmount(widget.totalFinal),
                        ),
                        if (widget.totalFinal < 50)
                          _PresetChip(
                            label: 'S/ 50',
                            onTap: () => _setPresetAmount(50),
                          ),
                        if (widget.totalFinal < 100)
                          _PresetChip(
                            label: 'S/ 100',
                            onTap: () => _setPresetAmount(100),
                          ),
                        if (widget.totalFinal < 200)
                          _PresetChip(
                            label: 'S/ 200',
                            onTap: () => _setPresetAmount(200),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Resultado de Vuelto / Falta
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            faltaDinero
                                ? AppColors.danger.withValues(alpha: 0.10)
                                : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              faltaDinero
                                  ? AppColors.danger.withValues(alpha: 0.3)
                                  : const Color(0xFF86EFAC),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                faltaDinero
                                    ? Icons.warning_amber_rounded
                                    : Icons.check_circle_outline_rounded,
                                size: 16,
                                color:
                                    faltaDinero
                                        ? AppColors.danger
                                        : const Color(0xFF15803D),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                faltaDinero ? 'Falta cobrar:' : 'Vuelto a dar:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      faltaDinero
                                          ? AppColors.danger
                                          : const Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'S/ ${(vuelto >= 0 ? vuelto : -vuelto).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color:
                                  faltaDinero
                                      ? AppColors.danger
                                      : const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Cancelar',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 4),
                  _KeyBadge('Esc'),
                ],
              ),
            ),
            FilledButton(
              onPressed: faltaDinero ? null : _confirm,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                disabledBackgroundColor: Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 18, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'Confirmar Venta',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(width: 6),
                  _KeyBadge('Enter', isPrimary: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PosSuccessDialog extends StatefulWidget {
  final bool isDraft;
  final Future<void> Function() onPrint;

  const PosSuccessDialog({
    super.key,
    required this.isDraft,
    required this.onPrint,
  });

  @override
  State<PosSuccessDialog> createState() => _PosSuccessDialogState();
}

class _PosSuccessDialogState extends State<PosSuccessDialog> {
  bool _isGenerating = false;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): () {
          Navigator.pop(context, true);
        },
      },
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (widget.isDraft ? AppColors.warning : AppColors.teal)
                      .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.isDraft
                      ? Icons.bookmark_added_rounded
                      : Icons.check_circle_rounded,
                  color: widget.isDraft ? AppColors.warning : AppColors.teal,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isDraft
                          ? 'Borrador Guardado'
                          : '¡Venta Exitosa!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.isDraft
                          ? 'La orden ha sido guardada en borradores.'
                          : 'El pedido fue procesado y el stock actualizado.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (!widget.isDraft)
              OutlinedButton.icon(
                onPressed:
                    _isGenerating
                        ? null
                        : () async {
                          setState(() => _isGenerating = true);
                          try {
                            await widget.onPrint();
                          } finally {
                            if (mounted) setState(() => _isGenerating = false);
                          }
                        },
                icon:
                    _isGenerating
                        ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.print_rounded, size: 18),
                label: Text(
                  _isGenerating ? 'Generando...' : 'Imprimir Ticket',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Nueva Venta',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(width: 6),
                  _KeyBadge('Enter', isPrimary: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _RowItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _KeyBadge extends StatelessWidget {
  final String keyText;
  final bool isPrimary;

  const _KeyBadge(this.keyText, {this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: isPrimary
            ? Colors.white.withValues(alpha: 0.25)
            : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        keyText,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isPrimary ? Colors.white : AppColors.textSecondary,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
