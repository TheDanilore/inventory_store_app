// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — CUENTAS FINANCIERAS  (crear / editar)
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/models/financial_account_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountsTab extends StatefulWidget {
  const AccountsTab({super.key});
  @override
  State<AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<AccountsTab>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  late Future<List<FinancialAccountModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _refresh() {
    final f = _load();
    setState(() {
      _future = f;
      return;
    });
  }

  Future<List<FinancialAccountModel>> _load() async {
    final response = await _supabase
        .from('financial_accounts')
        .select('id, name, type, balance, is_active, created_at')
        .order('is_active', ascending: false)
        .order('name');

    // CORRECCIÓN: Usar fromJson como está definido en los modelos que creamos
    return (response as List)
        .map(
          (e) => FinancialAccountModel.fromJson(
            Map<String, dynamic>.from(e as Map),
          ),
        )
        .toList();
  }

  Future<void> _openAccountSheet({FinancialAccountModel? account}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountFormSheet(account: account),
    );
    if (saved == true) _refresh();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<FinancialAccountModel>>(
      future: _future,
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final totalBalance = accounts
            .where((a) => a.isActive)
            .fold<double>(0, (s, a) => s + a.balance);
        final activeCount = accounts.where((a) => a.isActive).length;

        return Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    children: [
                      _SummaryChip(
                        label: 'Cuentas activas',
                        value: '$activeCount',
                        color: AppColors.primary,
                        icon: Icons.account_balance_rounded,
                      ),
                      const SizedBox(width: 8),
                      _SummaryChip(
                        label: 'Balance total',
                        value: 'S/ ${totalBalance.toStringAsFixed(2)}',
                        color:
                            totalBalance >= 0
                                ? AppColors.success
                                : AppColors.danger,
                        icon: Icons.payments_rounded,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child:
                      isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : accounts.isEmpty
                          ? const _EmptyState(
                            icon: Icons.account_balance_outlined,
                            message: 'No hay cuentas registradas',
                          )
                          : RefreshIndicator(
                            onRefresh: () async => _refresh(),
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                              itemCount: accounts.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 8),
                              itemBuilder:
                                  (_, i) => _AccountCard(
                                    account: accounts[i],
                                    onTap:
                                        () => _openAccountSheet(
                                          account: accounts[i],
                                        ),
                                  ),
                            ),
                          ),
                ),
              ],
            ),
            Positioned(
              bottom: 24,
              right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'fab_accounts',
                onPressed: () => _openAccountSheet(),
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text(
                  'Nueva cuenta',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Bottom Sheet: Crear / Editar cuenta ──────────────────────────────────────

class _AccountFormSheet extends StatefulWidget {
  final FinancialAccountModel? account;
  const _AccountFormSheet({this.account});

  @override
  State<_AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends State<_AccountFormSheet> {
  final _supabase = Supabase.instance.client;
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _type = 'CAJA';
  bool _isActive = true;
  bool _saving = false;

  static const _types = ['CAJA', 'BANCO', 'DIGITAL', 'OTRO'];

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameCtrl.text = widget.account!.name;
      _type = widget.account!.type;
      _isActive = widget.account!.isActive;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      if (_isEditing) {
        await _supabase
            .from('financial_accounts')
            .update({
              'name': _nameCtrl.text.trim(),
              'type': _type,
              'is_active': _isActive,
            })
            .eq('id', widget.account!.id);
      } else {
        final balance =
            double.tryParse(_balanceCtrl.text.replaceAll(',', '.')) ?? 0.0;
        await _supabase.from('financial_accounts').insert({
          'name': _nameCtrl.text.trim(),
          'type': _type,
          'balance': balance,
          'is_active': _isActive,
        });
      }

      // CORRECCIÓN: Salir limpiamente sin ejecutar el bloque finally
      // para evitar el error de "setState called after dispose" que congela la app.
      if (!mounted) return;
      Navigator.pop(context, true);
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }

    // Solo se quita el loader si hubo un error y NO se cerró el modal
    if (mounted) setState(() => _saving = false);
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
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              _isEditing ? 'Editar cuenta' : 'Nueva cuenta',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 20),

            _FieldLabel('Nombre de la cuenta'),
            TextFormField(
              controller: _nameCtrl,
              decoration: _inputDeco('Ej: Caja principal'),
              textCapitalization: TextCapitalization.sentences,
              validator:
                  (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 14),

            _FieldLabel('Tipo'),
            Wrap(
              spacing: 8,
              children:
                  _types.map((t) {
                    final selected = _type == t;
                    return GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              selected ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              selected
                                  ? null
                                  : Border.all(
                                    color: AppColors.textSecondary.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _accountTypeIcon(t),
                              size: 14,
                              color:
                                  selected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              t,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color:
                                    selected
                                        ? Colors.white
                                        : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 14),

            if (!_isEditing) ...[
              _FieldLabel('Balance inicial'),
              TextFormField(
                controller: _balanceCtrl,
                decoration: _inputDeco('0.00'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
              ),
              const SizedBox(height: 14),
            ],

            if (_isEditing) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Estado',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          _isActive ? 'Cuenta activa' : 'Cuenta inactiva',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    activeColor: AppColors.success,
                  ),
                ],
              ),
              const SizedBox(height: 14),
            ],

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
                        : Text(
                          _isEditing ? 'Guardar cambios' : 'Crear cuenta',
                          style: const TextStyle(
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

  IconData _accountTypeIcon(String type) {
    switch (type) {
      case 'CAJA':
        return Icons.point_of_sale_rounded;
      case 'BANCO':
        return Icons.account_balance_rounded;
      case 'DIGITAL':
        return Icons.phone_android_rounded;
      default:
        return Icons.savings_rounded;
    }
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

class _AccountCard extends StatelessWidget {
  final FinancialAccountModel account;
  final VoidCallback onTap;
  const _AccountCard({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = account.name;
    final type = account.type;
    final balance = account.balance;
    final isActive = account.isActive;

    Color typeColor;
    IconData typeIcon;
    switch (type.toUpperCase()) {
      case 'CAJA':
        typeIcon = Icons.point_of_sale_rounded;
        typeColor = AppColors.teal;
        break;
      case 'BANCO':
        typeIcon = Icons.account_balance_rounded;
        typeColor = AppColors.primary;
        break;
      case 'DIGITAL':
        typeIcon = Icons.phone_android_rounded;
        typeColor = Colors.purple.shade400;
        break;
      default:
        typeIcon = Icons.savings_rounded;
        typeColor = AppColors.textSecondary;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border:
              !isActive
                  ? Border.all(
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                  )
                  : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color:
                      isActive
                          ? typeColor.withValues(alpha: 0.12)
                          : AppColors.textSecondary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  typeIcon,
                  size: 22,
                  color: isActive ? typeColor : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: isActive ? null : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!isActive)
                          const _Badge(
                            label: 'Inactiva',
                            color: AppColors.textSecondary,
                          ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.edit_rounded,
                          size: 15,
                          color: AppColors.textSecondary.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      type,
                      style: TextStyle(
                        fontSize: 12,
                        color: isActive ? typeColor : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'S/ ${balance.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color:
                          balance >= 0 ? AppColors.success : AppColors.danger,
                    ),
                  ),
                  const Text(
                    'saldo',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 9,
                      color: color.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 52,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
