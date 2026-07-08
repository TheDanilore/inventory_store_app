import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/features/financial/data/models/financial_account_model.dart';
import 'package:inventory_store_app/features/pos/presentation/providers/cash_shifts_provider.dart';
import 'package:inventory_store_app/core/theme/app_colors.dart';
import 'package:inventory_store_app/core/widgets/app_snackbar.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OpenShiftSheet extends StatefulWidget {
  final List<FinancialAccountModel> accounts;
  const OpenShiftSheet({super.key, required this.accounts});

  static Future<bool?> show(BuildContext context, {required List<FinancialAccountModel> accounts}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OpenShiftSheet(accounts: accounts),
    );
  }

  @override
  State<OpenShiftSheet> createState() => _OpenShiftSheetState();
}

class _OpenShiftSheetState extends State<OpenShiftSheet> {
  final _supabase = Supabase.instance.client;
  final _amountCtrl = TextEditingController(text: '0.00');
  final _formKey = GlobalKey<FormState>();
  String? _selectedAccountId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.accounts.isNotEmpty) {
      _selectedAccountId = widget.accounts.first.id;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedAccountId == null) return;
    setState(() => _saving = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No hay sesión activa');

      final profileRes = await _supabase.from('profiles').select('id').eq('auth_user_id', user.id).maybeSingle();
      final profileId = profileRes?['id'] as String? ?? user.id;

      final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;

      final selectedAccount = widget.accounts.firstWhere((a) => a.id == _selectedAccountId);
      if (amount > selectedAccount.balance) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message: 'Saldo insuficiente. La cuenta solo tiene S/ ${selectedAccount.balance.toStringAsFixed(2)}',
            type: SnackbarType.error,
          );
          setState(() => _saving = false);
        }
        return;
      }

      await _supabase.from('cash_shifts').insert({
        'account_id': _selectedAccountId,
        'opened_by': profileId,
        'opening_amount': amount,
        'status': 'OPEN',
        'opened_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (!mounted) return;
      context.read<CashShiftsProvider>().fetchShifts();
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(context, message: 'Error al abrir turno: $e', type: SnackbarType.error);
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: const Icon(Icons.lock_open_rounded, color: AppColors.success, size: 22),
                ),
                const SizedBox(width: 10),
                const Text('Abrir turno de caja', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
            const SizedBox(height: 20),

            _FieldLabel('Cuenta'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedAccountId,
                  isExpanded: true,
                  items: widget.accounts.map((a) => DropdownMenuItem<String>(
                    value: a.id,
                    child: Row(
                      children: [
                        Icon(Icons.point_of_sale_rounded, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      ],
                    ),
                  )).toList(),
                  onChanged: (v) => v != null ? setState(() => _selectedAccountId = v) : null,
                ),
              ),
            ),
            const SizedBox(height: 14),

            _FieldLabel('Monto de apertura (S/)'),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
              decoration: InputDecoration(
                prefixText: 'S/ ',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa un monto';
                if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Monto inválido';
                return null;
              },
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Abrir turno', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
    );
