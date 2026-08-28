import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_cubit.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cash_shifts/cash_shifts_state.dart';

class OpenShiftSheet {
  /// Muestra un Dialog centrado en desktop y un BottomSheet en mobile.
  static Future<bool?> show(
    BuildContext context, {
    required List<Map<String, dynamic>> accounts,
  }) {
    final cashShiftsCubit = context.read<CashShiftsCubit>();
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    
    if (isDesktop) {
      return showDialog<bool>(
        context: context,
        barrierColor: Colors.black54,
        builder:
            (_) => BlocProvider.value(
              value: cashShiftsCubit,
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 80,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: _OpenShiftContent(accounts: accounts),
                ),
              ),
            ),
      );
    }
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => BlocProvider.value(
            value: cashShiftsCubit,
            child: _OpenShiftContent(accounts: accounts),
          ),
    );
  }
}

// ── Widget interno reutilizable (dialog y bottom sheet comparten el mismo) ──

class _OpenShiftContent extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
  const _OpenShiftContent({required this.accounts});

  @override
  State<_OpenShiftContent> createState() => _OpenShiftContentState();
}

class _OpenShiftContentState extends State<_OpenShiftContent> {
  final _amountCtrl = TextEditingController(text: '0.00');
  final _formKey = GlobalKey<FormState>();
  String? _selectedAccountId;

  @override
  void initState() {
    super.initState();
    if (widget.accounts.isNotEmpty) {
      _selectedAccountId = widget.accounts.first['id'];
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate() || _selectedAccountId == null) {
      return;
    }

    final amount =
        double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;

    // We delegate the opening to the Cubit (backend check & insertion)
    context.read<CashShiftsCubit>().openShift(_selectedAccountId!, amount);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    final bottom = isDesktop ? 0.0 : MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius:
            isDesktop
                ? BorderRadius.circular(20)
                : const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow:
            isDesktop
                ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 8),
                  ),
                ]
                : null,
      ),
      padding: EdgeInsets.fromLTRB(20, isDesktop ? 24 : 8, 20, 20 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isDesktop)
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
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_open_rounded,
                    color: AppColors.success,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Abrir turno de caja',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                if (isDesktop) ...[
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.textSecondary,
                    tooltip: 'Cerrar',
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            _FieldLabel('Cuenta'),
            if (widget.accounts.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No hay cuentas de tipo CAJA configuradas en el sistema.',
                        style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedAccountId,
                  isExpanded: true,
                  items:
                      widget.accounts
                          .map(
                            (a) => DropdownMenuItem<String>(
                              value: a['id'],
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.point_of_sale_rounded,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    a['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                  onChanged:
                      (v) =>
                          v != null
                              ? setState(() => _selectedAccountId = v)
                              : null,
                ),
              ),
            ),
            const SizedBox(height: 14),

            _FieldLabel('Monto de apertura (S/)'),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: InputDecoration(
                prefixText: 'S/ ',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa un monto';
                if (double.tryParse(v.replaceAll(',', '.')) == null) {
                  return 'Monto inválido';
                }
                return null;
              },
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
                    onPressed: (state.isLoading || widget.accounts.isEmpty) ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
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
                              'Abrir turno',
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
