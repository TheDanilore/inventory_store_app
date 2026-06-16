import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/models/financial_account_model.dart';
import 'package:inventory_store_app/providers/admin/account_movements_provider.dart';
import 'package:inventory_store_app/providers/admin/financial_accounts_provider.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _type = 'INCOME';
  String? _sourceAccountId;
  String? _destAccountId;

  List<FinancialAccountModel> _accounts = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Use accounts from the provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final accounts = context.read<FinancialAccountsProvider>().accounts.where((a) => a.isActive).toList();
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

  Future<String?> _getActiveShift(String accountId) async {
    final res = await _supabase
        .from('cash_shifts')
        .select('id')
        .eq('account_id', accountId)
        .eq('status', 'OPEN')
        .maybeSingle();
    return res?['id'] as String?;
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
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No hay sesión activa');

      final profileRes = await _supabase.from('profiles').select('id').eq('auth_user_id', user.id).maybeSingle();
      final profileId = profileRes?['id'] as String? ?? user.id;

      final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;

      // Consultar saldo actual de origen
      final sourceAccRes = await _supabase.from('financial_accounts').select('balance, name').eq('id', _sourceAccountId!).single();
      final currentSourceBalance = (sourceAccRes['balance'] as num).toDouble();
      final sourceName = sourceAccRes['name'] as String;

      final sourceShiftId = await _getActiveShift(_sourceAccountId!);

      if (_type == 'TRANSFER') {
        final destAccRes = await _supabase.from('financial_accounts').select('balance, name').eq('id', _destAccountId!).single();
        final currentDestBalance = (destAccRes['balance'] as num).toDouble();
        final destName = destAccRes['name'] as String;
        final destShiftId = await _getActiveShift(_destAccountId!);

        await _supabase.from('financial_accounts').update({'balance': currentSourceBalance - amount}).eq('id', _sourceAccountId!);
        await _supabase.from('financial_accounts').update({'balance': currentDestBalance + amount}).eq('id', _destAccountId!);

        await _supabase.from('account_movements').insert([
          {
            'account_id': _sourceAccountId,
            'movement_type': 'EXPENSE',
            'amount': amount,
            'description': 'Transferencia enviada a $destName${_descCtrl.text.trim().isNotEmpty ? ' — ${_descCtrl.text.trim()}' : ''}',
            'created_by': profileId,
            'shift_id': sourceShiftId,
            'reference_type': 'manual_transfer',
          },
          {
            'account_id': _destAccountId,
            'movement_type': 'INCOME',
            'amount': amount,
            'description': 'Transferencia recibida de $sourceName${_descCtrl.text.trim().isNotEmpty ? ' — ${_descCtrl.text.trim()}' : ''}',
            'created_by': profileId,
            'shift_id': destShiftId,
            'reference_type': 'manual_transfer',
          },
        ]);
      } else {
        final isIncome = _type == 'INCOME';
        final newBalance = isIncome ? (currentSourceBalance + amount) : (currentSourceBalance - amount);

        await _supabase.from('financial_accounts').update({'balance': newBalance}).eq('id', _sourceAccountId!);

        await _supabase.from('account_movements').insert({
          'account_id': _sourceAccountId,
          'movement_type': _type,
          'amount': amount,
          'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : 'Movimiento manual',
          'created_by': profileId,
          'shift_id': sourceShiftId,
          'reference_type': 'manual',
        });
      }

      if (!mounted) return;
      
      // Update both providers
      context.read<AccountMovementsProvider>().fetchMovements();
      context.read<FinancialAccountsProvider>().fetchAccounts();

      AppSnackbar.show(context, message: 'Movimiento registrado correctamente', type: SnackbarType.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, message: 'Error registrando movimiento: $e', type: SnackbarType.error);
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
        child: const Center(child: Text("Cargando cuentas...")),
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
                decoration: BoxDecoration(color: AppColors.textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Text('Nuevo Movimiento', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
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

            _FieldLabel(_type == 'TRANSFER' ? 'Cuenta Origen (De donde sale)' : 'Cuenta'),
            _AccountSelector(value: _sourceAccountId, accounts: _accounts, onChanged: (v) => setState(() => _sourceAccountId = v)),
            const SizedBox(height: 14),

            if (_type == 'TRANSFER') ...[
              _FieldLabel('Cuenta Destino (A donde entra)'),
              _AccountSelector(value: _destAccountId, accounts: _accounts, onChanged: (v) => setState(() => _destAccountId = v)),
              const SizedBox(height: 14),
            ],

            _FieldLabel('Monto (S/)'),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: _inputDeco('0.00').copyWith(prefixText: 'S/ '),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa un monto';
                if ((double.tryParse(v.replaceAll(',', '.')) ?? 0) <= 0) return 'Monto inválido';
                return null;
              },
            ),
            const SizedBox(height: 14),

            _FieldLabel('Descripción'),
            TextFormField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: _inputDeco('Ej. Aporte de capital, Pago de taxi...'),
              validator: (v) => (v == null || v.trim().isEmpty) && _type != 'TRANSFER' ? 'Requerido' : null,
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Guardar movimiento', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      );
}

// ignore: non_constant_identifier_names
Widget _FieldLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
          border: isSelected ? null : Border.all(color: AppColors.textSecondary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.white : AppColors.textSecondary),
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
  final List<FinancialAccountModel> accounts;
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
          items: accounts.map((a) {
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
                  Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
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
