import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';

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
  late TextEditingController _receivedCtrl;
  double _montoRecibido = 0.0;

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
    return list.take(4).toList();
  }

  bool _isConfirming = false;

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
          Navigator.pop(context, null);
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

                  // Calculadora de Vuelto en Efectivo
                  if (_isCashPayment) ...[
                    const SizedBox(height: 14),
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
                        _PresetChip(
                          label:
                              'Exacto (${widget.currencySymbol} ${widget.totalFinal.toStringAsFixed(2)})',
                          isSelected:
                              (_montoRecibido - widget.totalFinal).abs() < 0.01,
                          onTap: () => _setPresetAmount(widget.totalFinal),
                        ),
                        for (final preset in _calculatePresets())
                          _PresetChip(
                            label:
                                '${widget.currencySymbol} ${preset.toStringAsFixed(0)}',
                            isSelected: (_montoRecibido - preset).abs() < 0.01,
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
                    onPressed: (faltaDinero || _isConfirming) ? null : _confirm,
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

class PosSuccessDialog extends StatefulWidget {
  final bool isDraft;
  final Future<void> Function() onPrint;
  final double totalAmount;
  final double? amountReceived;
  final String paymentMethod;
  final String? customerName;
  final String? documentType;
  final String? documentSeries;
  final String? paymentReference;
  final String currencySymbol;

  const PosSuccessDialog({
    super.key,
    required this.isDraft,
    required this.onPrint,
    this.totalAmount = 0.0,
    this.amountReceived,
    this.paymentMethod = 'EFECTIVO',
    this.customerName,
    this.documentType,
    this.documentSeries,
    this.paymentReference,
    this.currencySymbol = 'S/',
  });

  @override
  State<PosSuccessDialog> createState() => _PosSuccessDialogState();
}

class _PosSuccessDialogState extends State<PosSuccessDialog> {
  bool _isGenerating = false;

  bool get _isCashPayment {
    final method = widget.paymentMethod.toUpperCase();
    return method.contains('EFECTIVO') || method.contains('CAJA');
  }

  double get _montoRecibido => widget.amountReceived ?? widget.totalAmount;

  @override
  Widget build(BuildContext context) {
    final vuelto = _montoRecibido - widget.totalAmount;
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
          Navigator.pop(context, true);
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isDraft ? 'Borrador Guardado' : '¡Venta Exitosa!',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
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
                            color: AppColors.teal.withValues(alpha: 0.12),
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
                                  widget.customerName?.isNotEmpty == true
                                      ? widget.customerName!
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

                  // Si es Borrador
                  if (widget.isDraft) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.warning.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'TOTAL DEL BORRADOR',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.currencySymbol} ${widget.totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                  // Si es Efectivo: Mostrar la tarjeta HERO DE VUELTO
                  else if (_isCashPayment) ...[
                    _buildCashVueltoHero(vuelto, faltaDinero),
                  ]
                  // Si es otro método (Yape, Plin, Banco, Crédito)
                  else ...[
                    _buildDigitalPaymentSummary(),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 320;

                final printBtn =
                    widget.isDraft
                        ? null
                        : OutlinedButton.icon(
                          onPressed:
                              _isGenerating
                                  ? null
                                  : () async {
                                    setState(() => _isGenerating = true);
                                    try {
                                      await widget.onPrint();
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isGenerating = false);
                                      }
                                    }
                                  },
                          icon:
                              _isGenerating
                                  ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Icon(Icons.print_rounded, size: 18),
                          label: Text(
                            _isGenerating ? 'Generando...' : 'Imprimir Ticket',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.teal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );

                final newSaleBtn = FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  label: const Text(
                    'Nueva Venta',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );

                if (isNarrow && printBtn != null) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [printBtn, const SizedBox(height: 8), newSaleBtn],
                  );
                }

                return Row(
                  children: [
                    if (printBtn != null) ...[
                      Expanded(child: printBtn),
                      const SizedBox(width: 10),
                    ],
                    Expanded(child: newSaleBtn),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashVueltoHero(double vuelto, bool faltaDinero) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            faltaDinero
                ? AppColors.danger.withValues(alpha: 0.08)
                : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              faltaDinero
                  ? AppColors.danger.withValues(alpha: 0.35)
                  : const Color(0xFF86EFAC),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    faltaDinero
                        ? Icons.warning_amber_rounded
                        : Icons.currency_exchange_rounded,
                    size: 16,
                    color:
                        faltaDinero
                            ? AppColors.danger
                            : const Color(0xFF15803D),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    faltaDinero ? 'MONTO INSUFICIENTE' : 'VUELTO A ENTREGAR',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color:
                          faltaDinero
                              ? AppColors.danger
                              : const Color(0xFF166534),
                    ),
                  ),
                ],
              ),
              if (!faltaDinero && vuelto.abs() < 0.01)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'PAGO EXACTO',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            faltaDinero
                ? 'Faltan ${widget.currencySymbol} ${(-vuelto).toStringAsFixed(2)}'
                : '${widget.currencySymbol} ${(vuelto >= 0 ? vuelto : 0.0).toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              color: faltaDinero ? AppColors.danger : const Color(0xFF15803D),
            ),
          ),
          const SizedBox(height: 10),
          Divider(
            height: 1,
            color:
                faltaDinero
                    ? AppColors.danger.withValues(alpha: 0.2)
                    : const Color(0xFFBBF7D0),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: ${widget.currencySymbol} ${widget.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Pagó con: ${widget.currencySymbol} ${_montoRecibido.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalPaymentSummary() {
    final method = widget.paymentMethod.toUpperCase();
    final isYape = method.contains('YAPE');
    final isPlin = method.contains('PLIN');
    final isCredit = method.contains('CRÉDITO') || method.contains('CREDITO');

    Color badgeColor;
    IconData badgeIcon;
    if (isYape) {
      badgeColor = const Color(0xFF732282); // Yape purple
      badgeIcon = Icons.phone_android_rounded;
    } else if (isPlin) {
      badgeColor = const Color(0xFF00A3E0); // Plin cyan
      badgeIcon = Icons.bolt_rounded;
    } else if (isCredit) {
      badgeColor = AppColors.warning;
      badgeIcon = Icons.credit_score_rounded;
    } else {
      badgeColor = const Color(0xFF2563EB); // Bank/card blue
      badgeIcon = Icons.credit_card_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 14, color: badgeColor),
                    const SizedBox(width: 5),
                    Text(
                      widget.paymentMethod,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 12,
                      color: Color(0xFF15803D),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'PAGADO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'TOTAL COBRADO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.currencySymbol} ${widget.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: AppColors.textPrimary,
            ),
          ),
          if (widget.paymentReference?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.receipt_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'N° Operación: ',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.paymentReference!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 13,
                color: AppColors.textMuted,
              ),
              SizedBox(width: 5),
              Text(
                'Pago electrónico confirmado sin cambio de efectivo.',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSelected;

  const _PresetChip({
    required this.label,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.teal : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.teal : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
