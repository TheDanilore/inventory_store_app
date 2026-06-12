// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — TURNOS DE CAJA  (abrir / cerrar)
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/models/cash_shift_model.dart';
import 'package:inventory_store_app/models/financial_account_model.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShiftsTab extends StatefulWidget {
  const ShiftsTab({super.key});
  @override
  State<ShiftsTab> createState() => _ShiftsTabState();
}

class _ShiftsTabState extends State<ShiftsTab>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  late Future<_ShiftsData> _future;
  String _filterStatus = 'Todos';

  // 🟢 NUEVAS variables de paginación
  static const int _pageSize = 8;
  int _currentPage = 0;

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

  Future<_ShiftsData> _load() async {
    final shiftsRes = await _supabase
        .from('cash_shifts')
        .select('''
          id, status, opening_amount, expected_amount, actual_amount,
          difference_amount, notes, opened_at, closed_at, account_id,
          financial_accounts(id, name, type),
          opened_by_profile:profiles!cash_shifts_opened_by_fkey(full_name),
          closed_by_profile:profiles!cash_shifts_closed_by_fkey(full_name)
        ''')
        .order('opened_at', ascending: false)
        .limit(100);

    // CORRECCIÓN: fromJson en lugar de fromMap
    final shifts =
        (shiftsRes as List)
            .map(
              (e) =>
                  CashShiftModel.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();

    final accountsRes = await _supabase
        .from('financial_accounts')
        .select('id, name, type, balance')
        .eq('is_active', true)
        .eq('type', 'CAJA')
        .order('name');

    final accounts =
        (accountsRes as List)
            .map(
              (e) => FinancialAccountModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();

    final openAccountIds =
        shifts
            .whereType<
              CashShiftModel
            >() // 1. Asegura que ningún elemento de la lista sea nulo
            .where((s) => s.status == 'OPEN')
            .map((s) => s.accountId)
            .whereType<
              String
            >() // 2. Filtra los accountId nulos (agrega esto también por el error anterior)
            .toSet();

    return _ShiftsData(
      shifts: shifts,
      accounts: accounts,
      openAccountIds: openAccountIds,
    );
  }

  Future<double> _calcExpected(
    String shiftId,
    String accountId,
    double openingAmount,
  ) async {
    final movRes = await _supabase
        .from('account_movements')
        .select('movement_type, amount')
        .eq('account_id', accountId)
        .eq('shift_id', shiftId);

    final movs =
        (movRes as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
    double income = 0;
    double expense = 0;
    for (final m in movs) {
      final amt = (m['amount'] as num).toDouble();
      if (m['movement_type'] == 'INCOME') income += amt;
      if (m['movement_type'] == 'EXPENSE') expense += amt;
    }
    return openingAmount + income - expense;
  }

  Future<void> _openOpenShiftSheet(
    List<FinancialAccountModel> accounts,
    Set<String> openAccountIds,
  ) async {
    final availableAccounts =
        accounts.where((a) => !openAccountIds.contains(a.id)).toList();
    if (availableAccounts.isEmpty) {
      AppSnackbar.show(
        context,
        message: 'Todas las cuentas ya tienen un turno abierto',
        type: SnackbarType.warning,
      );
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OpenShiftSheet(accounts: availableAccounts),
    );
    if (saved == true) _refresh();
  }

  Future<void> _openCloseShiftSheet(CashShiftModel shift) async {
    final expected = await _calcExpected(
      shift.id,
      shift.accountId ?? '',
      shift.openingAmount,
    );

    if (!mounted) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CloseShiftSheet(shift: shift, expectedAmount: expected),
    );
    if (saved == true) _refresh();
  }

  List<CashShiftModel> _applyFilters(List<CashShiftModel> shifts) {
    if (_filterStatus == 'Todos') return shifts;
    return shifts.where((s) => s.status == _filterStatus).toList();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<_ShiftsData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final allShifts = data?.shifts ?? [];
        final accounts = data?.accounts ?? [];
        final openAccountIds = data?.openAccountIds ?? {};
        final shifts = _applyFilters(allShifts);
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final openCount = allShifts.where((s) => s.status == 'OPEN').length;
        final closedCount = allShifts.where((s) => s.status == 'CLOSED').length;
        final openShifts = allShifts.where((s) => s.status == 'OPEN').toList();

        final totalPages =
            shifts.isEmpty ? 1 : (shifts.length / _pageSize).ceil();
        final safePage = _currentPage >= totalPages ? 0 : _currentPage;
        final pageStart = safePage * _pageSize;
        final pageEnd = (pageStart + _pageSize).clamp(0, shifts.length);
        final pageItems = shifts.sublist(pageStart, pageEnd);

        return Stack(
          children: [
            Column(
              children: [
                if (openShifts.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Column(
                      children:
                          openShifts
                              .map(
                                (s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _ActiveShiftBanner(
                                    shift: s,
                                    onClose: () => _openCloseShiftSheet(s),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    openShifts.isNotEmpty ? 4 : 14,
                    16,
                    0,
                  ),
                  child: Row(
                    children: [
                      _StatusChip(
                        label: 'Abiertos',
                        count: openCount,
                        color: AppColors.success,
                        selected: _filterStatus == 'OPEN',
                        onTap:
                            () => setState(() {
                              _filterStatus =
                                  _filterStatus == 'OPEN' ? 'Todos' : 'OPEN';
                              _currentPage = 0;
                            }),
                      ),
                      const SizedBox(width: 6),
                      _StatusChip(
                        label: 'Cerrados',
                        count: closedCount,
                        color: AppColors.textSecondary,
                        selected: _filterStatus == 'CLOSED',
                        onTap:
                            () => setState(() {
                              _filterStatus =
                                  _filterStatus == 'CLOSED'
                                      ? 'Todos'
                                      : 'CLOSED';
                              _currentPage = 0;
                            }),
                      ),
                      const Spacer(),
                      Text(
                        '${shifts.length} turno${shifts.length != 1 ? 's' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child:
                      isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : shifts.isEmpty
                          ? const _EmptyState(
                            icon: Icons.point_of_sale_outlined,
                            message: 'No hay turnos registrados',
                          )
                          // 🟢 NUEVO: Columna para separar la lista de la paginación
                          : Column(
                            children: [
                              // Info de "Mostrando X de Y"
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  4,
                                ),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Mostrando ${shifts.isEmpty ? 0 : pageStart + 1}–$pageEnd de ${shifts.length} turnos',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              // La lista scrolleable
                              Expanded(
                                child: RefreshIndicator(
                                  onRefresh: () async => _refresh(),
                                  child: ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      4,
                                      16,
                                      16,
                                    ),
                                    itemCount:
                                        pageItems.length, // Usamos pageItems
                                    separatorBuilder:
                                        (_, __) => const SizedBox(height: 8),
                                    itemBuilder:
                                        (_, i) => _ShiftCard(
                                          shift:
                                              pageItems[i], // Usamos pageItems
                                          onClose:
                                              pageItems[i].status == 'OPEN'
                                                  ? () => _openCloseShiftSheet(
                                                    pageItems[i],
                                                  )
                                                  : null,
                                        ),
                                  ),
                                ),
                              ),
                              // La paginación FIJA en la parte inferior
                              if (totalPages > 1)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    16,
                                    10,
                                  ),
                                  child: AdminPageBlocks(
                                    currentPage: _currentPage,
                                    totalPages: totalPages,
                                    onPageChanged:
                                        (page) =>
                                            setState(() => _currentPage = page),
                                  ),
                                ),
                            ],
                          ),
                ),
              ],
            ),
            Positioned(
              bottom: 24,
              right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'fab_shifts',
                onPressed:
                    isLoading
                        ? null
                        : () => _openOpenShiftSheet(accounts, openAccountIds),
                backgroundColor: AppColors.success,
                icon: const Icon(Icons.lock_open_rounded, color: Colors.white),
                label: const Text(
                  'Abrir turno',
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

class _ShiftsData {
  final List<CashShiftModel> shifts;
  final List<FinancialAccountModel> accounts;
  final Set<String> openAccountIds;
  const _ShiftsData({
    required this.shifts,
    required this.accounts,
    required this.openAccountIds,
  });
}

// ── Bottom Sheet: Abrir turno ─────────────────────────────────────────────────

class _OpenShiftSheet extends StatefulWidget {
  final List<FinancialAccountModel> accounts;
  const _OpenShiftSheet({required this.accounts});

  @override
  State<_OpenShiftSheet> createState() => _OpenShiftSheetState();
}

class _OpenShiftSheetState extends State<_OpenShiftSheet> {
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
    if (!_formKey.currentState!.validate() || _selectedAccountId == null) {
      return;
    }
    setState(() => _saving = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No hay sesión activa');

      final profileRes =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', user.id)
              .maybeSingle();
      final profileId = profileRes?['id'] as String? ?? user.id;

      final amount =
          double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;

      // ─── INICIO DE LA NUEVA VALIDACIÓN ──────────────────────────
      // Buscamos la cuenta seleccionada para ver cuánto saldo tiene
      final selectedAccount = widget.accounts.firstWhere(
        (a) => a.id == _selectedAccountId,
      );

      if (amount > selectedAccount.balance) {
        if (mounted) {
          AppSnackbar.show(
            context,
            message:
                'Saldo insuficiente. La cuenta solo tiene S/ ${selectedAccount.balance.toStringAsFixed(2)}',
            type: SnackbarType.error,
          );
          setState(() => _saving = false);
        }
        return; // Detenemos el guardado
      }
      // ─── FIN DE LA NUEVA VALIDACIÓN ─────────────────────────────

      await _supabase.from('cash_shifts').insert({
        'account_id': _selectedAccountId,
        'opened_by': profileId,
        'opening_amount': amount,
        'status': 'OPEN',
        'opened_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (!mounted) return;
      Navigator.pop(context, true);
      return;
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al abrir turno: $e',
          type: SnackbarType.error,
        );
      }
    }

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
              ],
            ),
            const SizedBox(height: 20),

            _FieldLabel('Cuenta'),
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
                              value: a.id,
                              child: Row(
                                children: [
                                  Icon(
                                    _accountTypeIcon(a.type),
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
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
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
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
                          'Abrir turno',
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

  IconData _accountTypeIcon(String type) {
    switch (type.toUpperCase()) {
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
}

// ── Bottom Sheet: Cerrar turno ────────────────────────────────────────────────

class _CloseShiftSheet extends StatefulWidget {
  final CashShiftModel shift;
  final double expectedAmount;
  const _CloseShiftSheet({required this.shift, required this.expectedAmount});

  @override
  State<_CloseShiftSheet> createState() => _CloseShiftSheetState();
}

class _CloseShiftSheetState extends State<_CloseShiftSheet> {
  final _supabase = Supabase.instance.client;
  final _actualCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  double? _difference;

  void _onAmountChanged(String v) {
    final actual = double.tryParse(v.replaceAll(',', '.'));
    setState(() {
      _difference = actual != null ? actual - widget.expectedAmount : null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('No hay sesión activa');

      // CORRECCIÓN: Para auth_user_id
      final profileRes =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', user.id)
              .maybeSingle();
      final profileId = profileRes?['id'] as String? ?? user.id;

      final actual = double.parse(_actualCtrl.text.replaceAll(',', '.'));
      final diff = actual - widget.expectedAmount;

      await _supabase
          .from('cash_shifts')
          .update({
            'status': 'CLOSED',
            'closed_by': profileId,
            'closed_at': DateTime.now().toUtc().toIso8601String(),
            'expected_amount': widget.expectedAmount,
            'actual_amount': actual,
            'difference_amount': diff,
            'notes':
                _notesCtrl.text.trim().isNotEmpty
                    ? _notesCtrl.text.trim()
                    : null,
          })
          .eq('id', widget.shift.id);

      // CORRECCIÓN Salida limpia
      if (!mounted) return;
      Navigator.pop(context, true);
      return;
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al cerrar turno: $e',
          type: SnackbarType.error,
        );
      }
    }
    if (mounted) setState(() => _saving = false);
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
    final accountName = widget.shift.accountName;
    final openingAmount = widget.shift.openingAmount;

    Color diffColor = AppColors.textSecondary;
    String diffLabel = '–';
    if (_difference != null) {
      if (_difference! > 0) {
        diffColor = AppColors.success;
        diffLabel = '+S/ ${_difference!.toStringAsFixed(2)}';
      } else if (_difference! < 0) {
        diffColor = AppColors.danger;
        diffLabel = '-S/ ${_difference!.abs().toStringAsFixed(2)}';
      } else {
        diffColor = AppColors.success;
        diffLabel = 'S/ 0.00 (exacto)';
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
                    Icons.lock_rounded,
                    color: AppColors.danger,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cerrar turno de caja',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Text(
                        accountName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // ELIMINADO EL EXPANDED EXTRA AQUÍ
                  _AmountTile(
                    label: 'Apertura',
                    value: 'S/ ${openingAmount.toStringAsFixed(2)}',
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  // ELIMINADO EL EXPANDED EXTRA AQUÍ
                  _AmountTile(
                    label: 'Esperado',
                    value: 'S/ ${widget.expectedAmount.toStringAsFixed(2)}',
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            _FieldLabel('Monto real contado (S/)'),
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
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa el monto contado';
                if (double.tryParse(v.replaceAll(',', '.')) == null) {
                  return 'Monto inválido';
                }
                return null;
              },
            ),

            if (_difference != null) ...[
              const SizedBox(height: 10),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: diffColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      _difference == 0
                          ? Icons.check_circle_rounded
                          : (_difference! > 0
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded),
                      size: 16,
                      color: diffColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Diferencia: $diffLabel',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: diffColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            _FieldLabel('Notas (opcional)'),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Observaciones del cierre...',
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
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
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
                          'Cerrar turno',
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
}

// ── Banner de turno activo (con botón cerrar) ─────────────────────────────────

class _ActiveShiftBanner extends StatelessWidget {
  final CashShiftModel shift;
  final VoidCallback onClose;
  const _ActiveShiftBanner({required this.shift, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final accountName = shift.accountName;
    final openedBy = shift.openedByName;
    final openingAmount = shift.openingAmount;
    final openedAt = shift.openedAt;

    final dt = openedAt.toLocal();
    final openedLabel =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.success.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Turno activo — $accountName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.success,
                  ),
                ),
                Text(
                  'S/ ${openingAmount.toStringAsFixed(2)} · $openedBy · $openedLabel',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.success.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onClose,
            icon: const Icon(
              Icons.lock_rounded,
              size: 14,
              color: AppColors.danger,
            ),
            label: const Text(
              'Cerrar',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card de turno ─────────────────────────────────────────────────────────────

class _ShiftCard extends StatelessWidget {
  final CashShiftModel shift;
  final VoidCallback? onClose;
  const _ShiftCard({required this.shift, this.onClose});

  @override
  Widget build(BuildContext context) {
    final status = shift.status;
    final isOpen = status == 'OPEN';
    final accountName = shift.accountName;
    final openedBy = shift.openedByName;
    final closedBy = shift.closedByName;
    final openingAmount = shift.openingAmount;
    final expectedAmount = shift.expectedAmount;
    final actualAmount = shift.actualAmount;
    final differenceAmount = shift.differenceAmount;
    final notes = shift.notes;
    final openedAt = shift.openedAt;
    final closedAt = shift.closedAt;

    String fmtDate(DateTime? dt) {
      if (dt == null) return '–';
      final local = dt.toLocal();
      return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    String durationLabel = '';
    if (closedAt != null) {
      final diff = closedAt.difference(openedAt);
      durationLabel = '${diff.inHours}h ${diff.inMinutes % 60}m';
    }

    final statusColor = isOpen ? AppColors.success : AppColors.textSecondary;
    Color diffColor = AppColors.textSecondary;
    if (differenceAmount != null) {
      if (differenceAmount > 0) diffColor = AppColors.success;
      if (differenceAmount < 0) diffColor = AppColors.danger;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border:
            isOpen
                ? Border.all(
                  color: AppColors.success.withValues(alpha: 0.4),
                  width: 1.5,
                )
                : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                    size: 22,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              accountName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _Badge(
                            label: isOpen ? 'ABIERTO' : 'CERRADO',
                            color: statusColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Abierto por $openedBy',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                _AmountTile(
                  label: 'Apertura',
                  value: 'S/ ${openingAmount.toStringAsFixed(2)}',
                  color: AppColors.textSecondary,
                ),
                if (expectedAmount != null) ...[
                  const SizedBox(width: 8),
                  _AmountTile(
                    label: 'Esperado',
                    value: 'S/ ${expectedAmount.toStringAsFixed(2)}',
                    color: AppColors.primary,
                  ),
                ],
                if (actualAmount != null) ...[
                  const SizedBox(width: 8),
                  _AmountTile(
                    label: 'Real',
                    value: 'S/ ${actualAmount.toStringAsFixed(2)}',
                    color: AppColors.teal,
                  ),
                ],
                if (differenceAmount != null) ...[
                  const SizedBox(width: 8),
                  _AmountTile(
                    label: 'Diferencia',
                    value:
                        '${differenceAmount >= 0 ? '+' : ''}S/ ${differenceAmount.toStringAsFixed(2)}',
                    color: diffColor,
                  ),
                ],
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            decoration: const BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.login_rounded,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      fmtDate(openedAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (closedAt != null) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.logout_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        fmtDate(closedAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (durationLabel.isNotEmpty) ...[
                      const Spacer(),
                      const Icon(
                        Icons.timer_outlined,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        durationLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (closedBy != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Cerrado por $closedBy',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
                if (notes != null && notes.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.notes_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          notes,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (isOpen && onClose != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onClose,
                      icon: const Icon(
                        Icons.lock_rounded,
                        size: 14,
                        color: AppColors.danger,
                      ),
                      label: const Text(
                        'Cerrar turno',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.danger.withValues(alpha: 0.5),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AmountTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: color.withValues(alpha: 0.7),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _StatusChip({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: selected ? Colors.white : color,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color:
                    selected
                        ? Colors.white.withValues(alpha: 0.85)
                        : color.withValues(alpha: 0.8),
              ),
            ),
          ],
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

// ignore: non_constant_identifier_names
Widget _FieldLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
  ),
);

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
