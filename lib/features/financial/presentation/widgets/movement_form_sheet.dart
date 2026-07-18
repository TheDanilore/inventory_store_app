import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/account_movements_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts_cubit.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts_state.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MovementFormSheet extends StatefulWidget {
  const MovementFormSheet({super.key});

  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MovementFormSheet(),
    );
  }

  @override
  State<MovementFormSheet> createState() => _MovementFormSheetState();
}

class _MovementFormSheetState extends State<MovementFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _type = 'INCOME';
  String? _sourceAccountId;
  String? _destAccountId;

  List<FinancialAccountEntity> _accounts = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accState = context.read<FinancialAccountsCubit>().state;
      final accounts =
          accState is FinancialAccountsLoaded
              ? accState.accounts.where((a) => a.isActive).toList()
              : <FinancialAccountEntity>[];
      setState(() {
        _accounts = accounts;
        if (_accounts.isNotEmpty) {
          _sourceAccountId = _accounts.first.id;
          if (_accounts.length > 1) {
            _destAccountId = _accounts[1].id;
          } else {
            _destAccountId = _accounts.first.id;
          }
        }
      });
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _sourceAccountId == null) return;

    if (_type == 'TRANSFER' && _sourceAccountId == _destAccountId) {
      AppSnackbar.show(
        context,
        message: 'La cuenta origen y destino no pueden ser la misma',
        type: SnackbarType.warning,
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final amount =
          double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final description = _descCtrl.text.trim();

      if (_type == 'TRANSFER') {
        if (_destAccountId == null) {
          throw Exception('Seleccione cuenta destino');
        }
        await context.read<AccountMovementsCubit>().transferFunds(
          sourceAccountId: _sourceAccountId!,
          destAccountId: _destAccountId!,
          amount: amount,
          description: description,
        );
      } else {
        await context.read<AccountMovementsCubit>().saveMovement(
          accountId: _sourceAccountId!,
          movementType: _type,
          amount: amount,
          description: description,
        );
      }

      if (!mounted) return;

      // Actualizar cuentas también para reflejar los nuevos saldos
      context.read<FinancialAccountsCubit>().fetchAccounts();

      AppSnackbar.show(
        context,
        message: 'Movimiento registrado correctamente',
        type: SnackbarType.success,
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error registrando movimiento: $e',
          type: SnackbarType.error,
        );
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    if (_accounts.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(child: Text('Cargando cuentas...')),
      );
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
            const Text(
              'Nuevo Movimiento',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 20),

            _FieldLabel('Tipo de movimiento'),
            Row(
              children: [
                Expanded(
                  child: _TypeToggle(
                    label: 'Ingreso',
                    icon: Icons.add_circle_rounded,
                    color: AppColors.success,
                    isSelected: _type == 'INCOME',
                    onTap: () => setState(() => _type = 'INCOME'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TypeToggle(
                    label: 'Egreso',
                    icon: Icons.remove_circle_rounded,
                    color: AppColors.danger,
                    isSelected: _type == 'EXPENSE',
                    onTap: () => setState(() => _type = 'EXPENSE'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TypeToggle(
                    label: 'Transfer.',
                    icon: Icons.swap_horiz_rounded,
                    color: AppColors.primary,
                    isSelected: _type == 'TRANSFER',
                    onTap: () => setState(() => _type = 'TRANSFER'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _FieldLabel(
              _type == 'TRANSFER' ? 'Cuenta Origen (De donde sale)' : 'Cuenta',
            ),
            _AccountSelector(
              value: _sourceAccountId,
              accounts: _accounts,
              onChanged: (v) => setState(() => _sourceAccountId = v),
            ),
            const SizedBox(height: 14),

            if (_type == 'TRANSFER') ...[
              _FieldLabel('Cuenta Destino (A donde entra)'),
              _AccountSelector(
                value: _destAccountId,
                accounts: _accounts,
                onChanged: (v) => setState(() => _destAccountId = v),
              ),
              const SizedBox(height: 14),
            ],

            _FieldLabel('Monto (S/)'),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: _inputDeco('0.00').copyWith(prefixText: 'S/ '),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa un monto';
                if ((double.tryParse(v.replaceAll(',', '.')) ?? 0) <= 0) {
                  return 'Monto inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            _FieldLabel('Descripción'),
            TextFormField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDeco('Ej. Aporte de capital, Pago de taxi...'),
              validator:
                  (v) =>
                      (v == null || v.trim().isEmpty) && _type != 'TRANSFER'
                          ? 'Requerido'
                          : null,
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _saving
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text(
                          'Guardar movimiento',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

// ignore: non_constant_identifier_names
Widget _FieldLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
  ),
);

class _TypeToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeToggle({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border:
              isSelected
                  ? null
                  : Border.all(
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                  ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountSelector extends StatelessWidget {
  final String? value;
  final List<FinancialAccountEntity> accounts;
  final ValueChanged<String?> onChanged;

  const _AccountSelector({
    required this.value,
    required this.accounts,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items:
              accounts.map((a) {
                IconData typeIcon = Icons.savings_rounded;
                if (a.type == 'CAJA') typeIcon = Icons.point_of_sale_rounded;
                if (a.type == 'BANCO') typeIcon = Icons.account_balance_rounded;
                if (a.type == 'DIGITAL') typeIcon = Icons.phone_android_rounded;

                return DropdownMenuItem<String>(
                  value: a.id,
                  child: Row(
                    children: [
                      Icon(typeIcon, size: 16, color: AppColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        a.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
