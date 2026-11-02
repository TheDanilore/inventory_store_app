import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/dialogs/pos_preset_chip.dart';

/// Diálogo modal de confirmación de venta POS.
/// Permite validar comprobante, cliente, método de pago y calcular vuelto en efectivo
/// de manera ultra-rápida (60/120 fps) con presets precalculados y RepaintBoundary.
class PosConfirmationDialog extends StatefulWidget {
  final double totalFinal;
  final String? clienteName;
  final String paymentMethod;
  final String? documentType;
  final String? documentSeries;
  final String currencySymbol;
  final double? initialAmountReceived;
  final VoidCallback? onConfirm;

  const PosConfirmationDialog({
    super.key,
    required this.totalFinal,
    this.clienteName,
    required this.paymentMethod,
    this.documentType,
    this.documentSeries,
    this.currencySymbol = 'S/',
    this.initialAmountReceived,
    this.onConfirm,
  });

  static Future<double?> show(
    BuildContext context, {
    required double totalFinal,
    String? clienteName,
    required String paymentMethod,
    String? documentType,
    String? documentSeries,
    String currencySymbol = 'S/',
    double? initialAmountReceived,
  }) {
    return showDialog<double>(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => PosConfirmationDialog(
            totalFinal: totalFinal,
            clienteName: clienteName,
            paymentMethod: paymentMethod,
            documentType: documentType,
            documentSeries: documentSeries,
            currencySymbol: currencySymbol,
            initialAmountReceived: initialAmountReceived,
          ),
    );
  }

  @override
  State<PosConfirmationDialog> createState() => _PosConfirmationDialogState();
}

class _PosConfirmationDialogState extends State<PosConfirmationDialog> {
  late final TextEditingController _receivedCtrl;
  late final List<double> _presets;
  double _montoRecibido = 0.0;
  bool _isConfirming = false;

  bool get _isCashPayment {
    final method = widget.paymentMethod.toUpperCase();
    return method.contains('EFECTIVO') || method.contains('CAJA');
  }

  @override
  void initState() {
    super.initState();
    _montoRecibido = widget.initialAmountReceived ?? widget.totalFinal;
    _receivedCtrl = TextEditingController(
      text: widget.totalFinal.toStringAsFixed(2),
    );
    // Optimización de rendimiento: Pre-cálculo O(1) de denominaciones solo una vez en initState
    _presets = _calculatePresets();
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

  List<double> _calculatePresets() {
    final t = widget.totalFinal;
    final candidates = [10.0, 20.0, 50.0, 100.0, 200.0];
    final list = <double>[];

    for (final c in candidates) {
      if (c >= t && (c - t).abs() > 0.01) {
        list.add(c);
      }
    }
    if (t > 150) {
      final next50 = ((t / 50).ceil()) * 50.0;
      if (!list.contains(next50) && (next50 - t).abs() > 0.01) {
        list.add(next50);
      }
      final next100 = ((t / 100).ceil()) * 100.0;
      if (!list.contains(next100) && (next100 - t).abs() > 0.01) {
        list.add(next100);
      }
    }
    list.sort();
    return List.unmodifiable(list.take(4));
  }

  void _confirm() {
    if (_isConfirming) return;
    setState(() => _isConfirming = true);
    Navigator.pop(context, _montoRecibido);
    widget.onConfirm?.call();
  }

  @override
  Widget build(BuildContext context) {
    final vuelto = _montoRecibido - widget.totalFinal;
    final faltaDinero = _isCashPayment && vuelto < -0.01;

    final docType =
        (widget.documentType ?? 'NOTA_VENTA')
            .replaceAll('_', ' ')
            .toUpperCase();
    final docSeries = widget.documentSeries;
    final docLabel =
        docSeries != null && docSeries.isNotEmpty
            ? '$docType • $docSeries'
            : docType;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.enter): () {
          if (!faltaDinero && !_isConfirming) _confirm();
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (!_isConfirming) Navigator.pop(context, null);
        },
      },
      child: Focus(
        autofocus: true,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Colors.white,
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 10),
          contentPadding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
          actionsPadding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
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
                      'Verifica los datos antes de procesar el pedido',
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
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),

                  // ── Barra informativa de Comprobante y Cliente ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            docLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.tealDark,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  widget.clienteName?.isNotEmpty == true
                                      ? widget.clienteName!
                                      : 'Cliente Varios',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Resumen de Método de pago
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.payment_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Método de pago',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          widget.paymentMethod,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

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
                          '${widget.currencySymbol} ${widget.totalFinal.toStringAsFixed(2)}',
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

                  // Calculadora de Vuelto en Efectivo aislada con RepaintBoundary
                  if (_isCashPayment) ...[
                    const SizedBox(height: 14),
                    RepaintBoundary(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'PAGO EN EFECTIVO',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _receivedCtrl,
                            keyboardType:
                                const TextInputType.numberWithOptions(
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
                              prefixText: '${widget.currencySymbol} ',
                              prefixStyle: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textSecondary,
                              ),
                              labelText: '¿Con cuánto paga el cliente?',
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
                              PosPresetChip(
                                label:
                                    'Exacto (${widget.currencySymbol} ${widget.totalFinal.toStringAsFixed(2)})',
                                isSelected:
                                    (_montoRecibido - widget.totalFinal).abs() <
                                    0.01,
                                onTap: () => _setPresetAmount(widget.totalFinal),
                              ),
                              for (final preset in _presets)
                                PosPresetChip(
                                  label:
                                      '${widget.currencySymbol} ${preset.toStringAsFixed(0)}',
                                  isSelected:
                                      (_montoRecibido - preset).abs() < 0.01,
                                  onTap: () => _setPresetAmount(preset),
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
                                      ? AppColors.danger.withValues(
                                        alpha: 0.10,
                                      )
                                      : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color:
                                    faltaDinero
                                        ? AppColors.danger.withValues(
                                          alpha: 0.3,
                                        )
                                        : const Color(0xFF86EFAC),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      faltaDinero
                                          ? Icons.warning_amber_rounded
                                          : Icons
                                              .check_circle_outline_rounded,
                                      size: 16,
                                      color:
                                          faltaDinero
                                              ? AppColors.danger
                                              : const Color(0xFF15803D),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      faltaDinero
                                          ? 'Falta cobrar:'
                                          : 'Vuelto a dar:',
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
                                  '${widget.currencySymbol} ${(vuelto >= 0 ? vuelto : -vuelto).toStringAsFixed(2)}',
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
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _isConfirming
                            ? null
                            : () => Navigator.pop(context, null),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed:
                        (faltaDinero || _isConfirming) ? null : _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        _isConfirming
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Confirmar Venta',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
