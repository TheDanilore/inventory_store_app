import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/features/customers/presentation/widgets/customers/form/customer_form_fields.dart';

/// Sección de configuración de línea de crédito y preview de endeudamiento
class CustomerCreditSection extends StatelessWidget {
  final bool isEditing;
  final bool hasCredit;
  final bool isUnlimited;
  final bool creditExistsInDb;
  final double currentDebt;
  final TextEditingController creditLimitCtrl;
  final ValueChanged<bool> onHasCreditChanged;
  final ValueChanged<bool> onUnlimitedChanged;

  const CustomerCreditSection({
    super.key,
    required this.isEditing,
    required this.hasCredit,
    required this.isUnlimited,
    required this.creditExistsInDb,
    required this.currentDebt,
    required this.creditLimitCtrl,
    required this.onHasCreditChanged,
    required this.onUnlimitedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const CustomerSectionHeader(
          icon: Icons.credit_card_rounded,
          title: 'Línea de crédito',
        ),
        const SizedBox(height: 12),

        // Toggle Crédito Activo / Sin Crédito
        CustomerToggleRow(
          icon: Icons.credit_score_rounded,
          iconColor: hasCredit ? AppColors.primary : AppColors.textMuted,
          title: hasCredit ? 'Línea de crédito activa' : 'Sin crédito',
          subtitle:
              hasCredit
                  ? 'El cliente puede comprar a crédito'
                  : 'Activa para asignar crédito al cliente',
          value: hasCredit,
          onChanged: onHasCreditChanged,
        ),

        if (hasCredit) ...[
          const SizedBox(height: 14),

          // Deuda actual (solo lectura en modo edición si ya existe en BD)
          if (isEditing && creditExistsInDb) ...[
            CustomerReadOnlyInfoRow(
              icon: Icons.money_off_rounded,
              iconColor:
                  currentDebt > 0 ? AppColors.danger : AppColors.textMuted,
              label: 'Deuda actual acumulada',
              value: 'S/ ${currentDebt.toStringAsFixed(2)}',
              note:
                  currentDebt > 0
                      ? 'Registra abonos desde Cuentas por Cobrar'
                      : null,
            ),
            const SizedBox(height: 14),
          ],

          // Selector de Límite: Infinito vs Tope en Soles
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CustomerCreditTypePill(
                    title: 'Límite Infinito (∞)',
                    subtitle: 'Sin tope máximo',
                    icon: Icons.all_inclusive_rounded,
                    isSelected: isUnlimited,
                    onTap: () {
                      creditLimitCtrl.clear();
                      onUnlimitedChanged(true);
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: CustomerCreditTypePill(
                    title: 'Límite en Soles',
                    subtitle: 'Tope máximo fijo',
                    icon: Icons.tune_rounded,
                    isSelected: !isUnlimited,
                    onTap: () => onUnlimitedChanged(false),
                  ),
                ),
              ],
            ),
          ),

          if (!isUnlimited) ...[
            const SizedBox(height: 14),
            const CustomerFieldLabel('Límite de crédito en Soles *'),
            CustomerStyledField(
              controller: creditLimitCtrl,
              hint: 'Ej: 500.00',
              prefixIcon: Icons.account_balance_wallet_rounded,
              prefixText: 'S/ ',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (v) {
                if (!hasCredit || isUnlimited) return null;
                final n = double.tryParse(v?.trim() ?? '');
                if (n == null || n <= 0) {
                  return 'Ingresa un límite válido mayor a 0';
                }
                if (isEditing && n < currentDebt && currentDebt > 0) {
                  return 'El límite no puede ser menor a la deuda actual (S/ ${currentDebt.toStringAsFixed(2)})';
                }
                return null;
              },
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.verified_rounded,
                    size: 18,
                    color: Color(0xFF16A34A),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Crédito ilimitado: el cliente podrá comprar a crédito sin restricción de tope máximo.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF15803D),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Preview reactivo de endeudamiento optimizado con ValueListenableBuilder
          const SizedBox(height: 12),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: creditLimitCtrl,
            builder: (context, value, _) {
              final limit =
                  isUnlimited
                      ? 0.0
                      : (double.tryParse(value.text.trim()) ?? 0.0);
              final debt = isEditing ? currentDebt : 0.0;
              final pct =
                  (!isUnlimited && limit > 0)
                      ? (debt / limit).clamp(0.0, 1.0)
                      : 0.0;
              final available =
                  isUnlimited
                      ? double.infinity
                      : (limit - debt).clamp(0.0, double.infinity);
              final isRisk = !isUnlimited && pct >= 0.8;
              final color = isRisk ? AppColors.danger : AppColors.success;

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Vista previa del crédito',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          isUnlimited
                              ? 'Límite Infinito (∞)'
                              : '${(pct * 100).toStringAsFixed(0)}% usado',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: isUnlimited ? 0.0 : pct,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: CustomerPreviewStat(
                            label: 'Deuda',
                            value: 'S/ ${debt.toStringAsFixed(2)}',
                            color:
                                debt > 0
                                    ? AppColors.danger
                                    : AppColors.textMuted,
                          ),
                        ),
                        Expanded(
                          child: CustomerPreviewStat(
                            label: 'Disponible',
                            value:
                                isUnlimited
                                    ? 'Ilimitado'
                                    : 'S/ ${available.toStringAsFixed(2)}',
                            color: AppColors.success,
                          ),
                        ),
                        Expanded(
                          child: CustomerPreviewStat(
                            label: 'Límite',
                            value:
                                isUnlimited
                                    ? 'Sin tope (∞)'
                                    : 'S/ ${limit.toStringAsFixed(2)}',
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 8),
          const CustomerInfoNote(
            text:
                'La deuda se actualiza automáticamente al registrar ventas y pagos. No se edita manualmente.',
          ),
        ],
      ],
    );
  }
}
