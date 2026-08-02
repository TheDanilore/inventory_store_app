import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_cubit.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_state.dart';

class CloseShiftSheet extends StatefulWidget {
  final CashShiftEntity shift;
  final double expectedAmount;

  const CloseShiftSheet({
    super.key,
    required this.shift,
    required this.expectedAmount,
  });

  static Future<bool?> show(
    BuildContext context, {
    required CashShiftEntity shift,
    required double expectedAmount,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => CloseShiftSheet(shift: shift, expectedAmount: expectedAmount),
    );
  }

  @override
  State<CloseShiftSheet> createState() => _CloseShiftSheetState();
}

class _CloseShiftSheetState extends State<CloseShiftSheet> {
  final _actualCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  double? _difference;

  void _onAmountChanged(String v) {
    final actual = double.tryParse(v.replaceAll(',', '.'));
    setState(() {
      _difference = actual != null ? actual - widget.expectedAmount : null;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final actual = double.parse(_actualCtrl.text.replaceAll(',', '.'));

    context.read<CashShiftsCubit>().closeShift(
      widget.shift.id,
      actual,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    );
  }

  @override
  void dispose() {
    _actualCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final accountName = widget.shift.accountName ?? '';
    final openingAmount = widget.shift.openingAmount;

    Color diffColor = AppColors.textSecondary;
    String diffLabel = '–';
    if (_difference != null) {
      if (_difference! > 0) {
        diffColor = AppColors.success;
        diffLabel = '+ S/ ${_difference!.toStringAsFixed(2)}';
      } else if (_difference! < 0) {
        diffColor = AppColors.danger;
        diffLabel = '- S/ ${_difference!.abs().toStringAsFixed(2)}';
      } else {
        diffColor = AppColors.success;
        diffLabel = 'Cuadre exacto (0.00)';
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_clock_rounded,
                    color: AppColors.danger,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Cerrar turno de caja',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _SummaryRow('Cuenta:', accountName),
                  const SizedBox(height: 8),
                  _SummaryRow(
                    'Monto inicial:',
                    'S/ ${openingAmount.toStringAsFixed(2)}',
                  ),
                  const Divider(height: 16),
                  _SummaryRow(
                    'Saldo Esperado:',
                    'S/ ${widget.expectedAmount.toStringAsFixed(2)}',
                    isHighlight: true,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _FieldLabel('Monto Físico/Real (S/)'),
            TextFormField(
              controller: _actualCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: _onAmountChanged,
              decoration: InputDecoration(
                prefixText: 'S/ ',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requerido';
                if (double.tryParse(v.replaceAll(',', '.')) == null) {
                  return 'Inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            _FieldLabel('Diferencia (Sobrante / Faltante)'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color:
                    _difference != null
                        ? diffColor.withValues(alpha: 0.08)
                        : AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      _difference != null
                          ? diffColor.withValues(alpha: 0.3)
                          : AppColors.border,
                ),
              ),
              child: Text(
                diffLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: diffColor,
                ),
              ),
            ),
            const SizedBox(height: 14),

            _FieldLabel('Observaciones (opcional)'),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Ej. Faltante por pago de pasajes...',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: BlocConsumer<CashShiftsCubit, CashShiftsState>(
                listenWhen:
                    (previous, current) =>
                        previous.isLoading && !current.isLoading,
                listener: (context, state) {
                  if (state.errorMessage.isNotEmpty) {
                    AppSnackbar.show(
                      context,
                      message: state.errorMessage,
                      type: SnackbarType.error,
                    );
                  } else {
                    Navigator.pop(context, true);
                  }
                },
                builder: (context, state) {
                  return ElevatedButton(
                    onPressed: state.isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child:
                        state.isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : const Text(
                              'Cerrar turno',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: non_constant_identifier_names
Widget _FieldLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
  ),
);

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlight;
  final Color? color;

  const _SummaryRow(
    this.label,
    this.value, {
    this.isHighlight = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color:
                isHighlight ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
            fontSize: isHighlight ? 15 : 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color ?? AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: isHighlight ? 16 : 14,
          ),
        ),
      ],
    );
  }
}
