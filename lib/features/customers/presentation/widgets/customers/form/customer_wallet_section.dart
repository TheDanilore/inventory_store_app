import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/form/customer_form_fields.dart';

/// Sección de gestión de saldo y ajuste manual de monedas de lealtad
class CustomerWalletSection extends StatelessWidget {
  final double currentWalletBalance;
  final TextEditingController walletAdjustCtrl;

  const CustomerWalletSection({
    super.key,
    required this.currentWalletBalance,
    required this.walletAdjustCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomerSectionHeader(
          icon: Icons.stars_rounded,
          title: 'Billetera de monedas',
        ),
        const SizedBox(height: 12),

        // Saldo actual (solo lectura)
        CustomerReadOnlyInfoRow(
          icon: Icons.account_balance_wallet_rounded,
          iconColor: Colors.amber.shade700,
          label: 'Saldo actual',
          value: '$currentWalletBalance monedas',
        ),
        const SizedBox(height: 12),

        // Ajuste manual (puede ser negativo)
        const CustomerFieldLabel('Ajuste manual (puede ser negativo)'),
        CustomerStyledField(
          controller: walletAdjustCtrl,
          hint: '0',
          prefixIcon: Icons.add_circle_outline_rounded,
          prefixIconColor: Colors.amber.shade700,
          keyboardType: const TextInputType.numberWithOptions(signed: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
            LengthLimitingTextInputFormatter(6),
          ],
          validator: (v) {
            if (v == null || v.trim().isEmpty || v == '0') {
              return null; // sin cambio, OK
            }
            final delta = int.tryParse(v.trim());
            if (delta == null) return 'Valor inválido';
            final newBalance = currentWalletBalance + delta;
            if (newBalance < 0) {
              return 'El saldo resultante no puede ser negativo';
            }
            return null;
          },
        ),

        // Preview reactivo eficiente mediante ValueListenableBuilder (sin setState en formulario)
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: walletAdjustCtrl,
          builder: (context, value, _) {
            final delta = double.tryParse(value.text.trim()) ?? 0.0;
            if (delta == 0) return const SizedBox.shrink();

            final newBalance = currentWalletBalance + delta;
            final isValid = newBalance >= 0;
            final color =
                !isValid
                    ? AppColors.danger
                    : delta > 0
                    ? AppColors.success
                    : Colors.orange;

            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(
                      delta > 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$currentWalletBalance ${delta > 0 ? "+" : ""}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                    Text(
                      '$newBalance monedas',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        const CustomerInfoNote(
          text:
              'El ajuste queda registrado en el historial de movimientos de billetera.',
        ),
      ],
    );
  }
}
