import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_state.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_cubit.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';

/// Tarjeta integrada en Caja / Checkout para seleccionar de forma instantánea
/// el tipo de comprobante (Nota de Venta, Boleta, Factura), serie, moneda y datos fiscales.
class PosDocumentAndCurrencyCard extends StatefulWidget {
  final double totalFinal;

  const PosDocumentAndCurrencyCard({super.key, required this.totalFinal});

  @override
  State<PosDocumentAndCurrencyCard> createState() =>
      _PosDocumentAndCurrencyCardState();
}

class _PosDocumentAndCurrencyCardState
    extends State<PosDocumentAndCurrencyCard> {
  final TextEditingController _refCtrl = TextEditingController();
  final TextEditingController _docNumberCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final posCubit = context.read<PosCubit>();
    _refCtrl.text = posCubit.state.paymentReference ?? '';
    _docNumberCtrl.text = posCubit.state.customerDocumentNumber ?? '';
    _addressCtrl.text = posCubit.state.customerAddress ?? '';
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _docNumberCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  bool _shouldShowReference(PosState posState) {
    if (posState.paymentMethod == 'CRÉDITO') return false;

    // 1. Si hay cuenta financiera seleccionada, verificar su tipo formal
    if (posState.selectedAccountId != null) {
      final acc = posState.accounts.firstWhere(
        (a) => a['id'] == posState.selectedAccountId,
        orElse: () => <String, dynamic>{},
      );
      final accType = (acc['type'] as String? ?? '').toUpperCase();
      if (accType == 'CAJA') return false;
      if (accType == 'DIGITAL' || accType == 'BANCO') return true;
    }

    // 2. Fallback por nombre del método de pago
    final m = posState.paymentMethod.toUpperCase();
    if (m.contains('CAJA') || m.contains('EFECTIVO') || m.contains('CRÉDITO')) {
      return false;
    }
    return m.contains('YAPE') ||
        m.contains('PLIN') ||
        m.contains('BCP') ||
        m.contains('BBVA') ||
        m.contains('INTERBANK') ||
        m.contains('SCOTIA') ||
        m.contains('BANCO') ||
        m.contains('TRANSFER') ||
        m.contains('TARJETA') ||
        m.contains('IZIPAY') ||
        m.contains('NIUBIZ') ||
        m.contains('DIGITAL');
  }

  @override
  Widget build(BuildContext context) {
    final posCubit = context.read<PosCubit>();

    return BlocBuilder<PosCubit, PosState>(
      buildWhen:
          (prev, curr) =>
              prev.documentType != curr.documentType ||
              prev.selectedSeries != curr.selectedSeries ||
              prev.currencyCode != curr.currencyCode ||
              prev.exchangeRate != curr.exchangeRate ||
              prev.paymentMethod != curr.paymentMethod ||
              prev.paymentReference != curr.paymentReference ||
              prev.selectedAccountId != curr.selectedAccountId ||
              prev.selectedClientId != curr.selectedClientId ||
              prev.customerDocumentNumber != curr.customerDocumentNumber ||
              prev.documentSeries != curr.documentSeries,
      builder: (context, posState) {
        if ((posState.paymentReference == null ||
                posState.paymentReference!.isEmpty) &&
            _refCtrl.text.isNotEmpty) {
          _refCtrl.clear();
        }

        final docType = posState.documentType;
        final isFactura = docType == 'FACTURA';
        final isBoleta = docType == 'BOLETA';
        final showRef = _shouldShowReference(posState);

        // Series disponibles para el tipo actual
        final seriesList =
            posState.documentSeries
                .where((s) => s.documentType == docType && s.isActive)
                .map((s) => s.series)
                .toList();

        if (seriesList.isEmpty) {
          seriesList.add(
            docType == 'FACTURA'
                ? 'F001'
                : (docType == 'BOLETA' ? 'B001' : 'NV01'),
          );
        }

        final currentSeries =
            seriesList.contains(posState.selectedSeries)
                ? posState.selectedSeries!
                : seriesList.first;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.radius),
            border: Border.all(color: AppColors.border),
            boxShadow: AppColors.cardShadow(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header de Sección ─────────────────────────────────────
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    size: 15,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'COMPROBANTE Y MONEDA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isFactura
                              ? Colors.purple.shade50
                              : (isBoleta
                                  ? Colors.blue.shade50
                                  : AppColors.teal.withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color:
                            isFactura
                                ? Colors.purple.shade200
                                : (isBoleta
                                    ? Colors.blue.shade200
                                    : AppColors.teal.withValues(alpha: 0.3)),
                      ),
                    ),
                    child: Text(
                      '$currentSeries • ${posState.currencyCode}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color:
                            isFactura
                                ? Colors.purple.shade700
                                : (isBoleta
                                    ? Colors.blue.shade700
                                    : AppColors.teal),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Selector de Comprobante (Segmented Rápido) ──────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  return Row(
                    children: [
                      _DocTypeChip(
                        label: 'NOTA DE VENTA',
                        icon: Icons.receipt_outlined,
                        isSelected: docType == 'NOTA_VENTA',
                        onTap: () => posCubit.setDocumentType('NOTA_VENTA'),
                      ),
                      const SizedBox(width: 6),
                      _DocTypeChip(
                        label: 'BOLETA',
                        icon: Icons.description_outlined,
                        isSelected: docType == 'BOLETA',
                        onTap: () => posCubit.setDocumentType('BOLETA'),
                      ),
                      const SizedBox(width: 6),
                      _DocTypeChip(
                        label: 'FACTURA',
                        icon: Icons.business_outlined,
                        isSelected: docType == 'FACTURA',
                        onTap: () => posCubit.setDocumentType('FACTURA'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // ── Fila de Serie y Moneda ─────────────────────────────────
              Row(
                children: [
                  // Serie Dropdown
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: currentSeries,
                      isDense: true,
                      decoration: InputDecoration(
                        labelText: 'Serie',
                        labelStyle: const TextStyle(fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                      items:
                          seriesList.map((s) {
                            return DropdownMenuItem<String>(
                              value: s,
                              child: Text(s),
                            );
                          }).toList(),
                      onChanged: (val) {
                        if (val != null) posCubit.setDocumentSeries(val);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Moneda Base Oficial del Sistema ERP (Fija, configurada por el Administrador en Ajustes)
                  Expanded(
                    flex: 1,
                    child: BlocBuilder<AppConfigCubit, AppConfigState>(
                      builder: (context, configState) {
                        final base = configState.baseCurrency;

                        // Sincronizar automáticamente con la moneda base configurada en el sistema
                        if (posState.currencyCode != base.code) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (context.mounted) {
                              posCubit.setCurrency(
                                base.code,
                                base.exchangeRate,
                              );
                            }
                          });
                        }

                        return Tooltip(
                          message:
                              'Moneda oficial configurada en Ajustes del Sistema (${base.name})',
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.teal.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    base.symbol.trim(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.tealDark,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${base.code} (${base.symbol.trim()})',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Text(
                                        'Moneda Sistema',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              // ── Preview de Moneda Extranjera si aplica ─────────────────
              if (posState.currencyCode != 'PEN') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.currency_exchange_rounded,
                        size: 14,
                        color: Colors.amber.shade800,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'T.C: ${posState.exchangeRate.toStringAsFixed(4)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade900,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Equivalente: ${posState.currencyCode == "USD" ? "\$" : posState.currencyCode} ${(widget.totalFinal / (posState.exchangeRate > 0 ? posState.exchangeRate : 1.0)).toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Validación / Alerta Fiscal para Factura ────────────────
              if (isFactura) ...[
                const SizedBox(height: 10),
                _buildFacturaFiscalInfo(context, posState),
              ],

              // ── Alerta SUNAT Boleta >= S/ 700 ─────────────────────────
              if (isBoleta && widget.totalFinal >= 700.0) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: Colors.orange.shade800,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'SUNAT: Boletas >= S/ 700 requieren registrar cliente con DNI/RUC.',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.brown,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Campo Nº Operación / Referencia (Digital / Tarjeta) ────
              if (showRef) ...[
                const SizedBox(height: 10),
                TextFormField(
                  controller: _refCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nº Operación / Voucher (Opcional)',
                    hintText: 'Ej: 987456, Yape #, Lote...',
                    helperText:
                        'Nº de constancia de Yape, Plin o voucher para cuadre de caja',
                    helperStyle: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                    labelStyle: const TextStyle(fontSize: 12),
                    hintStyle: const TextStyle(fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    prefixIcon: const Icon(Icons.pin_rounded, size: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  style: const TextStyle(fontSize: 12),
                  onChanged: (val) => posCubit.setPaymentReference(val.trim()),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildFacturaFiscalInfo(BuildContext context, PosState posState) {
    final clientName = posState.selectedClientName;
    final docNum = posState.customerDocumentNumber?.trim() ?? '';
    final hasRuc = docNum.length == 11;

    if (posState.selectedClientId == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Factura requiere seleccionar un cliente con RUC válido (11 dígitos).',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (!hasRuc) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.orange.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cliente "$clientName" no tiene un RUC de 11 dígitos (${docNum.isEmpty ? "Sin documento" : docNum}).',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _docNumberCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              decoration: InputDecoration(
                labelText: 'Completar RUC (11 dígitos)',
                labelStyle: const TextStyle(fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (val) {
                context.read<PosCubit>().setCustomerFiscalData(
                  customerDocType: 'RUC',
                  customerDocNumber: val.trim(),
                  customerAddress: _addressCtrl.text.trim(),
                );
              },
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 15, color: Colors.green),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'RUC: $docNum • $clientName',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.green.shade800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocTypeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _DocTypeChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? (label == 'FACTURA'
                          ? Colors.purple.shade600
                          : (label == 'BOLETA'
                              ? Colors.blue.shade600
                              : AppColors.teal))
                      : AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.transparent : AppColors.border,
                width: 1.2,
              ),
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: (label == 'FACTURA'
                                  ? Colors.purple
                                  : (label == 'BOLETA'
                                      ? Colors.blue
                                      : AppColors.teal))
                              .withValues(alpha: 0.25),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
