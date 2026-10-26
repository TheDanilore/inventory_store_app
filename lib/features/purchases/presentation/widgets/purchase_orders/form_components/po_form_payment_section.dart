import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/app_config/presentation/bloc/app_config_cubit.dart';
import 'package:inventory_store_app/features/financial/data/models/financial_account_model.dart';
import 'po_form_section_widgets.dart';

class POFormPaymentSection extends StatelessWidget {
  final bool isEditing;
  final String paymentMode;
  final String paymentStatus;
  final String? selectedAccountId;
  final List<FinancialAccountModel> accounts;
  final Map<String, String> activeShiftsByAccount;
  final double totalAmount;
  final String currencyCode;
  final double exchangeRate;
  final String? creditWarningMessage;
  final void Function(String code, double rate) onCurrencyChanged;
  final ValueChanged<String> onPaymentModeChanged;
  final ValueChanged<String> onPaymentStatusChanged;
  final ValueChanged<String?> onAccountChanged;

  const POFormPaymentSection({
    super.key,
    required this.isEditing,
    required this.paymentMode,
    required this.paymentStatus,
    required this.selectedAccountId,
    required this.accounts,
    required this.activeShiftsByAccount,
    required this.totalAmount,
    required this.currencyCode,
    required this.exchangeRate,
    required this.creditWarningMessage,
    required this.onCurrencyChanged,
    required this.onPaymentModeChanged,
    required this.onPaymentStatusChanged,
    required this.onAccountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final validAccountId =
        accounts.any((a) => a.id == selectedAccountId)
            ? selectedAccountId
            : null;

    return POFormSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const POFormSectionTitle(
            icon: Icons.payments_rounded,
            title: 'Condiciones de Pago',
          ),
          const SizedBox(height: 16),

          // Selector de Moneda de Compra
          Builder(
            builder: (context) {
              final appConfig = context.watch<AppConfigCubit>();
              final activeCurrencies = appConfig.activeCurrencies;
              if (activeCurrencies.length <= 1) return const SizedBox.shrink();

              final isForeign = currencyCode != 'PEN';

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.currency_exchange_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Moneda de la Compra',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (isForeign)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Text(
                              'T.C: ${exchangeRate.toStringAsFixed(4)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children:
                          activeCurrencies.map((c) {
                            final isSel = currencyCode == c.code;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () {
                                    onCurrencyChanged(
                                      c.code,
                                      c.exchangeRateToTarget,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isSel
                                              ? AppColors.primary
                                              : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color:
                                            isSel
                                                ? AppColors.primary
                                                : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${c.symbol} ${c.code}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color:
                                              isSel
                                                  ? Colors.white
                                                  : AppColors.textPrimary,
                                        ),
                                      ),
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
            },
          ),

          DropdownButtonFormField<String>(
            key: ValueKey('mode_$paymentMode'),
            initialValue: paymentMode,
            isExpanded: true,
            icon: const Icon(Icons.expand_more_rounded),
            decoration: poFormDropdownDecoration(
              'Modo de Pago',
              icon: Icons.money_rounded,
            ),
            items: const [
              DropdownMenuItem(
                value: 'EFECTIVO',
                child: Text(
                  'Efectivo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              DropdownMenuItem(
                value: 'TARJETA',
                child: Text(
                  'Tarjeta / Transferencia',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              DropdownMenuItem(
                value: 'CRÉDITO',
                child: Text(
                  'Línea de Crédito',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
            onChanged: (v) {
              if (v != null) {
                onPaymentModeChanged(v);
              }
            },
          ),
          const SizedBox(height: 16),
          if (isEditing) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Estado de pago: PENDIENTE. Los abonos y pagos se gestionan desde el detalle de la orden.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (paymentMode != 'CRÉDITO') ...[
            DropdownButtonFormField<String>(
              key: ValueKey('status_$paymentStatus'),
              initialValue: paymentStatus,
              icon: const Icon(Icons.expand_more_rounded),
              decoration: poFormDropdownDecoration(
                'Estado del Pago',
                icon: Icons.hourglass_top_rounded,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'PENDING',
                  child: Text(
                    'Pago Pendiente',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DropdownMenuItem(
                  value: 'PAID',
                  child: Text(
                    'Pago Realizado / Adelantado',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.success,
                    ),
                  ),
                ),
              ],
              onChanged: (v) {
                if (v != null) onPaymentStatusChanged(v);
              },
            ),
            if (paymentStatus == 'PAID') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('account_$validAccountId'),
                initialValue: validAccountId,
                isExpanded: true,
                icon: const Icon(Icons.expand_more_rounded),
                decoration: poFormDropdownDecoration(
                  'Cuenta Origen',
                  icon: Icons.account_balance_wallet_rounded,
                ),
                items:
                    accounts.map((acc) {
                      return DropdownMenuItem(
                        value: acc.id,
                        child: Text(
                          '${acc.name} (Saldo: S/ ${acc.balance.toStringAsFixed(2)})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                onChanged: onAccountChanged,
              ),
              if (validAccountId != null) ...[
                Builder(
                  builder: (context) {
                    final selectedAcc = accounts.firstWhere(
                      (a) => a.id == validAccountId,
                      orElse: () => accounts.first,
                    );

                    final accType = selectedAcc.type;
                    final isCaja = accType == 'CAJA';
                    final hasOpenShift = activeShiftsByAccount.containsKey(
                      validAccountId,
                    );
                    final isInsufficientBalance =
                        selectedAcc.balance < totalAmount;

                    return Column(
                      children: [
                        if (isCaja && !hasOpenShift)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.warning,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Esta caja ("${selectedAcc.name}") no tiene un turno abierto. Debes abrir un turno de caja antes de registrar un pago realizado.',
                                    style: const TextStyle(
                                      color: AppColors.warning,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (isInsufficientBalance)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Saldo insuficiente en "${selectedAcc.name}". Saldo disponible: S/ ${selectedAcc.balance.toStringAsFixed(2)} | Requerido: S/ ${totalAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ] else ...[
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.credit_score_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Se utilizará la línea de crédito acordada con el proveedor.',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (creditWarningMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.block_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      creditWarningMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
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
}
