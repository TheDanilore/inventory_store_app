import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/pos/domain/utils/pos_calculator_utils.dart';
import 'package:inventory_store_app/features/pos/presentation/widgets/pos_checkout/quick_create_customer_dialog.dart';

/// Modal inteligente de cobro, facturación y emisión de comprobantes en el POS.
class PosPaymentSheet extends StatefulWidget {
  final double totalFinal;
  final double pointsToSolesRatio;
  final double earningRate;
  final String? initialCustomerName;
  final Map<String, int> soldQuantities;
  final void Function(Map<String, int> soldQuantities)? onSaleCompleted;

  const PosPaymentSheet({
    super.key,
    required this.totalFinal,
    this.pointsToSolesRatio = 100.0,
    this.earningRate = 0.05,
    this.initialCustomerName,
    this.soldQuantities = const {},
    this.onSaleCompleted,
  });

  /// Despliega el modal de cobro adaptándose a desktop o móvil
  static Future<bool?> show(
    BuildContext context, {
    required double totalFinal,
    double pointsToSolesRatio = 100.0,
    double earningRate = 0.05,
    String? initialCustomerName,
    Map<String, int> soldQuantities = const {},
    void Function(Map<String, int> soldQuantities)? onSaleCompleted,
  }) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    if (isMobile) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder:
            (sheetCtx) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetCtx).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(sheetCtx).size.height * 0.92,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: PosPaymentSheet(
                  totalFinal: totalFinal,
                  pointsToSolesRatio: pointsToSolesRatio,
                  earningRate: earningRate,
                  initialCustomerName: initialCustomerName,
                  soldQuantities: soldQuantities,
                  onSaleCompleted: onSaleCompleted,
                ),
              ),
            ),
      );
    }

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogCtx) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620, maxHeight: 760),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F000000),
                      blurRadius: 32,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: PosPaymentSheet(
                  totalFinal: totalFinal,
                  pointsToSolesRatio: pointsToSolesRatio,
                  earningRate: earningRate,
                  initialCustomerName: initialCustomerName,
                  soldQuantities: soldQuantities,
                  onSaleCompleted: onSaleCompleted,
                ),
              ),
            ),
          ),
    );
  }

  @override
  State<PosPaymentSheet> createState() => _PosPaymentSheetState();
}

class _PosPaymentSheetState extends State<PosPaymentSheet> {
  late TextEditingController _receivedCtrl;
  late TextEditingController _refCtrl;
  final FocusNode _receivedFocus = FocusNode();

  double _montoRecibido = 0.0;
  final bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<PosCubit>();
    final appConfig = context.read<AppConfigCubit>();
    if (appConfig.state.currencies.isEmpty) {
      appConfig.loadCurrencies();
    }

    final initialRate =
        cubit.state.exchangeRate > 0 ? cubit.state.exchangeRate : 1.0;
    final initialTotal =
        cubit.state.currencyCode == 'PEN'
            ? widget.totalFinal
            : double.parse(
              (widget.totalFinal / initialRate).toStringAsFixed(2),
            );

    _montoRecibido = initialTotal;
    _receivedCtrl = TextEditingController(
      text: initialTotal.toStringAsFixed(2),
    );
    _refCtrl = TextEditingController();

    // Sincronizar referencia inicial si ya existe en cubit
    if (cubit.state.paymentReference != null) {
      _refCtrl.text = cubit.state.paymentReference!;
    }
  }

  @override
  void dispose() {
    _receivedCtrl.dispose();
    _refCtrl.dispose();
    _receivedFocus.dispose();
    super.dispose();
  }

  bool _isCash(String paymentMethod) {
    final m = paymentMethod.toUpperCase();
    return m.contains('EFECTIVO') || m.contains('CAJA');
  }

  bool _isCredit(String paymentMethod) {
    return paymentMethod.toUpperCase().contains('CRÉDITO');
  }

  void _onReceivedChanged(String val) {
    final parsed = double.tryParse(val) ?? 0.0;
    setState(() => _montoRecibido = parsed);
  }

  void _setPresetAmount(double amount) {
    _receivedCtrl.text = amount.toStringAsFixed(2);
    setState(() => _montoRecibido = amount);
  }

  String? _validateFiscalRequirements(PosState state) {
    final total = widget.totalFinal;
    final docType = state.documentType;

    // Regla SUNAT Factura: Cliente obligatorio con RUC de 11 dígitos
    if (docType == 'FACTURA') {
      final docNum = state.customerDocumentNumber?.trim() ?? '';
      if (state.selectedClientId == null) {
        return 'Para emitir Factura es obligatorio seleccionar o registrar un cliente.';
      }
      if (docNum.length != 11) {
        return 'La Factura requiere un cliente con RUC válido (11 dígitos). El cliente seleccionado tiene: ${docNum.isEmpty ? "Sin documento" : docNum}.';
      }
    }

    // Regla SUNAT Boleta >= S/ 700: Requiere identificación del cliente
    if (docType == 'BOLETA' && total >= 700.0) {
      final docNum = state.customerDocumentNumber?.trim() ?? '';
      if (state.selectedClientId == null || docNum.isEmpty) {
        return 'SUNAT: Boletas iguales o mayores a S/ 700 requieren registrar DNI/RUC del cliente.';
      }
    }

    // Validación de efectivo
    if (_isCash(state.paymentMethod) && !_isCredit(state.paymentMethod)) {
      final isForeign = state.currencyCode != 'PEN';
      final rate = state.exchangeRate > 0 ? state.exchangeRate : 1.0;
      final expectedAmount =
          isForeign
              ? double.parse((widget.totalFinal / rate).toStringAsFixed(2))
              : widget.totalFinal;
      final symbol =
          state.currencyCode == 'USD'
              ? '\$'
              : (state.currencyCode == 'EUR' ? '€' : 'S/');

      if (_montoRecibido < (expectedAmount - 0.01)) {
        final falta = expectedAmount - _montoRecibido;
        return 'Monto recibido insuficiente. Faltan $symbol ${falta.toStringAsFixed(2)}.';
      }
    }

    return null;
  }

  void _handleConfirm() {
    if (_isProcessing) return;

    final posCubit = context.read<PosCubit>();

    final validationError = _validateFiscalRequirements(posCubit.state);
    if (validationError != null) {
      AppSnackbar.show(
        context,
        message: validationError,
        type: SnackbarType.error,
      );
      return;
    }

    // Guardar referencia en el estado
    posCubit.setPaymentReference(
      _refCtrl.text.trim().isNotEmpty ? _refCtrl.text.trim() : null,
    );

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PosCubit, PosState>(
      builder: (context, state) {
        final isCash = _isCash(state.paymentMethod);
        final isCredit = _isCredit(state.paymentMethod);
        final isForeign = state.currencyCode != 'PEN';
        final rate = state.exchangeRate > 0 ? state.exchangeRate : 1.0;
        final totalInCurrency =
            isForeign
                ? double.parse((widget.totalFinal / rate).toStringAsFixed(2))
                : widget.totalFinal;
        final vuelto = _montoRecibido - totalInCurrency;
        final subtotal = double.parse(
          (totalInCurrency / 1.18).toStringAsFixed(2),
        );
        final igv = double.parse(
          (totalInCurrency - subtotal).toStringAsFixed(2),
        );
        final validationError = _validateFiscalRequirements(state);

        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.enter): () {
              if (validationError == null && !_isProcessing) _handleConfirm();
            },
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (!_isProcessing) Navigator.of(context).pop(false);
            },
          },
          child: Focus(
            autofocus: true,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── HEADER ──────────────────────────────────────────────────
                _buildHeader(context, state, totalInCurrency),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // ── BODY SCROLLABLE ─────────────────────────────────────────
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 18,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Selector de Cliente
                        _buildClientSection(context, state),
                        const SizedBox(height: 18),

                        // 2. Moneda de Cobro & Tipo de Cambio
                        _buildCurrencySection(context, state),
                        const SizedBox(height: 18),

                        // 3. Selector de Tipo de Comprobante (Tabs) & Serie
                        _buildDocumentSection(context, state),
                        const SizedBox(height: 18),

                        // Banner de advertencia fiscal (si aplica)
                        if (validationError != null)
                          _buildValidationAlert(validationError),

                        if (validationError != null) const SizedBox(height: 18),

                        // 4. Método de Pago y Cuentas
                        _buildPaymentMethodSection(context, state),
                        const SizedBox(height: 18),

                        // 5. Pago en Efectivo (Calculadora y Vuelto) o Referencia Digital
                        if (isCash && !isCredit) ...[
                          _buildCashCalculatorSection(
                            vuelto,
                            state,
                            totalInCurrency,
                          ),
                          const SizedBox(height: 18),
                        ] else if (!isCredit) ...[
                          _buildDigitalRefSection(),
                          const SizedBox(height: 18),
                        ],

                        // 6. Desglose Contable y Resumen
                        _buildAccountingSummary(
                          state,
                          subtotal,
                          igv,
                          totalInCurrency,
                        ),
                      ],
                    ),
                  ),
                ),

                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // ── FOOTER ACTIONS ──────────────────────────────────────────
                _buildFooter(context, validationError),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    PosState state,
    double totalInCurrency,
  ) {
    final isForeign = state.currencyCode != 'PEN';
    final symbol =
        state.currencyCode == 'USD'
            ? '\$'
            : (state.currencyCode == 'EUR' ? '€' : 'S/');

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 20, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.point_of_sale_rounded,
              color: AppColors.teal,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Procesar Pago - Caja',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  state.activeShift != null
                      ? 'Turno abierto • ${state.paymentMethod}'
                      : 'Configura comprobante y registra el cobro',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$symbol ${totalInCurrency.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.teal,
                  ),
                ),
                if (isForeign)
                  Text(
                    'S/ ${widget.totalFinal.toStringAsFixed(2)} (base)',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
            tooltip: 'Cerrar (Esc)',
          ),
        ],
      ),
    );
  }

  Widget _buildClientSection(BuildContext context, PosState state) {
    final posCubit = context.read<PosCubit>();
    final hasClient = state.selectedClientId != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'CLIENTE RECEPTOR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Color(0xFF64748B),
              ),
            ),
            InkWell(
              onTap: () async {
                final newCustomer = await QuickCreateCustomerDialog.show(
                  context,
                );
                if (newCustomer != null) {
                  final docNum = newCustomer.documentNumber;
                  final docType =
                      newCustomer.documentType ??
                      (docNum != null && docNum.length == 11
                          ? 'RUC'
                          : (docNum != null && docNum.length == 8
                              ? 'DNI'
                              : null));
                  posCubit.setClient(
                    newCustomer.id,
                    newCustomer.fullName,
                    0,
                    docNumber: docNum,
                    docType: docType,
                  );
                }
              },
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 15, color: AppColors.teal),
                    SizedBox(width: 4),
                    Text(
                      'Nuevo Cliente',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (hasClient)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 18,
                    color: AppColors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.selectedClientName ?? 'Cliente',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (state.customerDocumentNumber != null &&
                              state.customerDocumentNumber!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${state.customerDocumentType ?? "DOC"}: ${state.customerDocumentNumber}',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          if (state.customerAddress != null &&
                              state.customerAddress!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                state.customerAddress!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                  tooltip: 'Quitar cliente (Público General)',
                  onPressed: () => posCubit.removeClient(),
                ),
              ],
            ),
          )
        else
          Autocomplete<Map<String, dynamic>>(
            optionsBuilder: (textEditingValue) async {
              if (textEditingValue.text.trim().isEmpty) {
                return const Iterable<Map<String, dynamic>>.empty();
              }
              await posCubit.searchClients(textEditingValue.text);
              return posCubit.state.clientMatches;
            },
            displayStringForOption:
                (option) =>
                    '${option['full_name']} (${option['document_number'] ?? 'Sin doc'})',
            onSelected: (option) {
              final docNum = option['document_number'] as String?;
              final docType =
                  docNum != null && docNum.length == 11
                      ? 'RUC'
                      : (docNum != null && docNum.length == 8 ? 'DNI' : null);
              posCubit.setClient(
                option['id'] as String,
                option['full_name'] as String,
                (option['wallet_balance'] as num?)?.toInt() ?? 0,
                docNumber: docNum,
                docType: docType,
              );
            },
            fieldViewBuilder: (
              context,
              controller,
              focusNode,
              onFieldSubmitted,
            ) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  hintText:
                      'Buscar cliente por DNI, RUC o nombre (o dejar Público General)',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.teal,
                      width: 1.5,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCurrencySection(BuildContext context, PosState state) {
    final appConfigCubit = context.watch<AppConfigCubit>();
    final activeCurrencies = appConfigCubit.activeCurrencies;
    final posCubit = context.read<PosCubit>();

    if (activeCurrencies.length <= 1) {
      return const SizedBox.shrink();
    }

    final isForeign = state.currencyCode != 'PEN';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.currency_exchange_rounded,
                size: 16,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 8),
              const Text(
                'MONEDA DE COBRO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Color(0xFF64748B),
                ),
              ),
              const Spacer(),
              if (isForeign)
                InkWell(
                  onTap: () => _showEditRateDialog(context, state),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'T.C: ${state.exchangeRate.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.amber.shade900,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit_outlined,
                          size: 12,
                          color: Colors.amber.shade900,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children:
                activeCurrencies.map((curr) {
                  final isSelected = state.currencyCode == curr.code;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () {
                          posCubit.setCurrency(
                            curr.code,
                            curr.exchangeRateToTarget,
                          );
                          final rate =
                              curr.exchangeRateToTarget > 0
                                  ? curr.exchangeRateToTarget
                                  : 1.0;
                          final newAmount =
                              curr.code == 'PEN'
                                  ? widget.totalFinal
                                  : double.parse(
                                    (widget.totalFinal / rate).toStringAsFixed(
                                      2,
                                    ),
                                  );
                          _receivedCtrl.text = newAmount.toStringAsFixed(2);
                          setState(() => _montoRecibido = newAmount);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.teal : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color:
                                  isSelected
                                      ? AppColors.teal
                                      : const Color(0xFFCBD5E1),
                              width: isSelected ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                curr.symbol,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : AppColors.teal,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                curr.code,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      isSelected
                                          ? Colors.white
                                          : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  void _showEditRateDialog(BuildContext context, PosState state) {
    final ctrl = TextEditingController(
      text: state.exchangeRate.toStringAsFixed(4),
    );
    final posCubit = context.read<PosCubit>();

    showDialog(
      context: context,
      builder:
          (dCtx) => AlertDialog(
            title: Row(
              children: [
                const Icon(
                  Icons.currency_exchange_rounded,
                  color: AppColors.teal,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ajustar T.C. (${state.currencyCode})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingresa el tipo de cambio acordado para este comprobante (1 ${state.currencyCode} = X Soles):',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,4}'),
                    ),
                  ],
                  decoration: const InputDecoration(
                    prefixText: 'S/ ',
                    labelText: 'Tipo de cambio',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nota: Este tipo de cambio se congelará en este comprobante histórico.',
                  style: TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dCtx).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  final newRate = double.tryParse(ctrl.text.trim());
                  if (newRate != null && newRate > 0) {
                    posCubit.setExchangeRate(newRate);
                    final newAmount = double.parse(
                      (widget.totalFinal / newRate).toStringAsFixed(2),
                    );
                    _receivedCtrl.text = newAmount.toStringAsFixed(2);
                    setState(() => _montoRecibido = newAmount);
                    Navigator.of(dCtx).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Aplicar'),
              ),
            ],
          ),
    );
  }

  Widget _buildDocumentSection(BuildContext context, PosState state) {
    final posCubit = context.read<PosCubit>();
    final activeDocType = state.documentType;
    final seriesList = state.activeSeriesList;
    final effectiveSeries = state.effectiveSeries;

    final docTypes = [
      {'key': 'NOTA_VENTA', 'label': 'Nota de venta', 'badge': 'Interno'},
      {'key': 'BOLETA', 'label': 'Boleta', 'badge': 'SUNAT'},
      {'key': 'FACTURA', 'label': 'Factura', 'badge': 'RUC'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'TIPO DE COMPROBANTE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),

        // Tabs de Tipo
        Row(
          children:
              docTypes.map((type) {
                final isSelected = activeDocType == type['key'];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => posCubit.setDocumentType(type['key']!),
                      borderRadius: BorderRadius.circular(12),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? AppColors.teal
                                  : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                isSelected
                                    ? AppColors.teal
                                    : const Color(0xFFE2E8F0),
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              type['label']!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color:
                                    isSelected
                                        ? Colors.white
                                        : const Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              type['badge']!,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color:
                                    isSelected
                                        ? Colors.white.withValues(alpha: 0.85)
                                        : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
        ),

        const SizedBox(height: 12),

        // Selector de Serie de comprobante
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.confirmation_number_outlined,
                size: 18,
                color: Color(0xFF64748B),
              ),
              const SizedBox(width: 10),
              const Text(
                'Serie de emisión:',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              const Spacer(),
              if (seriesList.length > 1)
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: effectiveSeries,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                    items:
                        seriesList
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.series,
                                child: Text(s.series),
                              ),
                            )
                            .toList(),
                    onChanged: (val) {
                      if (val != null) posCubit.setDocumentSeries(val);
                    },
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    effectiveSeries,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.teal,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildValidationAlert(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFDC2626),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF991B1B),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection(BuildContext context, PosState state) {
    final posCubit = context.read<PosCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MÉTODO DE PAGO Y CUENTA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),

        // Cuentas disponibles
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              state.accounts.map((acc) {
                final isSelected = state.selectedAccountId == acc['id'];
                final name = acc['name'] as String? ?? 'Cuenta';
                final isCash = PosCalculatorUtils.accountRequiresShift(acc);

                return InkWell(
                  onTap: () => posCubit.setSelectedAccountId(acc['id']),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? AppColors.teal.withValues(alpha: 0.12)
                              : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isSelected
                                ? AppColors.teal
                                : const Color(0xFFE2E8F0),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isCash
                              ? Icons.payments_outlined
                              : Icons.account_balance_wallet_outlined,
                          size: 16,
                          color:
                              isSelected
                                  ? AppColors.teal
                                  : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight:
                                isSelected ? FontWeight.w800 : FontWeight.w600,
                            color:
                                isSelected
                                    ? AppColors.teal
                                    : const Color(0xFF334155),
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.check_circle_rounded,
                            size: 15,
                            color: AppColors.teal,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildCashCalculatorSection(
    double vuelto,
    PosState state,
    double totalInCurrency,
  ) {
    final falta = vuelto < -0.01;
    final isForeign = state.currencyCode != 'PEN';
    final symbol =
        state.currencyCode == 'USD'
            ? '\$'
            : (state.currencyCode == 'EUR' ? '€' : 'S/');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PAGO EN EFECTIVO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),

        // Input de Monto recibido
        TextField(
          controller: _receivedCtrl,
          focusNode: _receivedFocus,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          onChanged: _onReceivedChanged,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
          decoration: InputDecoration(
            prefixText: '$symbol ',
            prefixStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
            labelText: 'Monto recibido en efectivo (${state.currencyCode})',
            labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.teal, width: 1.8),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // Chips de denominaciones rápidas
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _PresetChip(
              label: 'Exacto ($symbol ${totalInCurrency.toStringAsFixed(2)})',
              onTap: () => _setPresetAmount(totalInCurrency),
            ),
            if (state.currencyCode == 'PEN') ...[
              if (totalInCurrency < 50)
                _PresetChip(label: 'S/ 50', onTap: () => _setPresetAmount(50)),
              if (totalInCurrency < 100)
                _PresetChip(
                  label: 'S/ 100',
                  onTap: () => _setPresetAmount(100),
                ),
              if (totalInCurrency < 200)
                _PresetChip(
                  label: 'S/ 200',
                  onTap: () => _setPresetAmount(200),
                ),
            ] else ...[
              if (totalInCurrency < 20)
                _PresetChip(label: '\$ 20', onTap: () => _setPresetAmount(20)),
              if (totalInCurrency < 50)
                _PresetChip(label: '\$ 50', onTap: () => _setPresetAmount(50)),
              if (totalInCurrency < 100)
                _PresetChip(
                  label: '\$ 100',
                  onTap: () => _setPresetAmount(100),
                ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Indicador de Vuelto o Falta
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: falta ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: falta ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    falta
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color:
                        falta
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF16A34A),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    falta ? 'Falta dinero:' : 'Vuelto a devolver:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color:
                          falta
                              ? const Color(0xFF991B1B)
                              : const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$symbol ${(falta ? -vuelto : vuelto).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color:
                          falta
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF16A34A),
                    ),
                  ),
                  if (isForeign && !falta && vuelto > 0.01)
                    Text(
                      'Equiv: S/ ${(vuelto * state.exchangeRate).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDigitalRefSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'REFERENCIA DIGITAL / BANCARIA',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _refCtrl,
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.receipt_long_outlined,
              size: 18,
              color: Color(0xFF94A3B8),
            ),
            hintText: 'Nº Operación / Referencia (ej. Yape, Plin, Tarjeta)',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountingSummary(
    PosState state,
    double subtotal,
    double igv,
    double totalInCurrency,
  ) {
    final isForeign = state.currencyCode != 'PEN';
    final symbol =
        state.currencyCode == 'USD'
            ? '\$'
            : (state.currencyCode == 'EUR' ? '€' : 'S/');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Op. Gravada (Subtotal):',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              Text(
                '$symbol ${subtotal.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'I.G.V. (18%):',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              Text(
                '$symbol ${igv.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL A PAGAR:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              Text(
                '$symbol ${totalInCurrency.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
          if (isForeign) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Equiv. Moneda Base (T.C. ${state.exchangeRate.toStringAsFixed(4)}):',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.amber.shade900,
                    ),
                  ),
                  Text(
                    'S/ ${widget.totalFinal.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, String? validationError) {
    final canConfirm = validationError == null && !_isProcessing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed:
                _isProcessing ? null : () => Navigator.of(context).pop(false),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            child: const Text(
              'Cancelar (Esc)',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: canConfirm ? _handleConfirm : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF94A3B8),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                _isProcessing
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                    : const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Confirmar Venta (Enter)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}
