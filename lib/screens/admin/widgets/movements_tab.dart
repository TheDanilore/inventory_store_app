// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — MOVIMIENTOS DE CUENTAS
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/models/account_movement_model.dart';
import 'package:inventory_store_app/models/financial_account_model.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/screens/admin/widgets/date_filter_calendar.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MovementsTab extends StatefulWidget {
  const MovementsTab({super.key});
  @override
  State<MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends State<MovementsTab>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  late Future<List<AccountMovementModel>> _future;
  String _filterType = 'Todos';
  String _filterAccount = 'Todas';
  List<String> _accountNames = ['Todas'];
  List<String>? _pendingAccountNames;
  final _searchCtrl = TextEditingController();
  String _searchText = '';

  static const int _pageSize = 8;
  int _currentPage = 0;

  DateTime? _dateFrom;
  DateTime? _dateTo;

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

  Future<List<AccountMovementModel>> _load() async {
    final response = await _supabase
        .from('account_movements')
        .select(
          'id, movement_type, amount, description, reference_type, reference_id, created_at, financial_accounts(id, name, type), profiles(full_name)',
        )
        .order('created_at', ascending: false)
        .limit(200);

    final list =
        (response as List)
            .map(
              (e) => AccountMovementModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList();

    final names =
        list.map((m) => m.accountName ?? '–').toSet().toList()..sort();
    _pendingAccountNames = ['Todas', ...names];

    return list;
  }

  List<AccountMovementModel> _applyFilters(List<AccountMovementModel> data) {
    return data.where((m) {
      final desc = (m.description).toLowerCase();
      final matchSearch =
          _searchText.isEmpty || desc.contains(_searchText.toLowerCase());
      final matchType = _filterType == 'Todos' || m.movementType == _filterType;
      final accName = m.accountName ?? '–';
      final matchAccount =
          _filterAccount == 'Todas' || accName == _filterAccount;
      final matchDate =
          (_dateFrom == null || !m.createdAt.isBefore(_dateFrom!)) &&
          (_dateTo == null || !m.createdAt.isAfter(_dateTo!));
      return matchSearch && matchType && matchAccount && matchDate;
    }).toList();
  }

  Future<void> _openMovementSheet() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MovementFormSheet(),
    );
    if (saved == true) _refresh();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<AccountMovementModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasData && _pendingAccountNames != null) {
          _accountNames = _pendingAccountNames!;
          _pendingAccountNames = null;
        }
        final allMovements = snapshot.data ?? [];
        final movements = _applyFilters(allMovements);
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final totalIncome = movements
            .where((m) => m.movementType == 'INCOME')
            .fold<double>(0, (s, m) => s + m.amount);
        final totalExpense = movements
            .where((m) => m.movementType == 'EXPENSE')
            .fold<double>(0, (s, m) => s + m.amount);

        // Lógica de paginación en cliente
        final totalPages =
            movements.isEmpty ? 1 : (movements.length / _pageSize).ceil();
        final safePage = _currentPage >= totalPages ? 0 : _currentPage;
        final pageStart = safePage * _pageSize;
        final pageEnd = (pageStart + _pageSize).clamp(0, movements.length);
        final pageItems = movements.sublist(pageStart, pageEnd);

        return Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    children: [
                      _SummaryChip(
                        label: 'Ingresos',
                        value: 'S/ ${totalIncome.toStringAsFixed(2)}',
                        color: AppColors.success,
                        icon: Icons.trending_up_rounded,
                      ),
                      const SizedBox(width: 8),
                      _SummaryChip(
                        label: 'Egresos',
                        value: 'S/ ${totalExpense.toStringAsFixed(2)}',
                        color: AppColors.danger,
                        icon: Icons.trending_down_rounded,
                      ),
                      const SizedBox(width: 8),
                      _SummaryChip(
                        label: 'Registros',
                        value: '${movements.length}',
                        color: AppColors.primary,
                        icon: Icons.receipt_long_rounded,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Row(
                    children: [
                      for (final t in [
                        'Todos',
                        'INCOME',
                        'EXPENSE',
                        'TRANSFER',
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: _FilterChip(
                            label: _typeLabel(t),
                            color: _typeColor(t),
                            selected: _filterType == t,
                            onTap:
                                () => setState(() {
                                  _filterType = _filterType == t ? 'Todos' : t;
                                  _currentPage = 0;
                                }),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          onChanged:
                              (v) => setState(() {
                                _searchText = v;
                                _currentPage = 0;
                              }),
                          decoration: InputDecoration(
                            hintText: 'Buscar descripción...',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              size: 20,
                            ),
                            suffixIcon:
                                _searchText.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() {
                                          _searchText = '';
                                          _currentPage = 0;
                                        });
                                      },
                                    )
                                    : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: AppColors.surface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _AccountDropdown(
                        accounts: _accountNames,
                        selected: _filterAccount,
                        onChanged:
                            (v) => setState(() {
                              _filterAccount = v;
                              _currentPage = 0;
                            }),
                      ),
                      const SizedBox(width: 8),
                      // NUEVO USO DEL BOTÓN
                      DateFilterCalendar(
                        dateRange:
                            _dateFrom != null && _dateTo != null
                                ? DateTimeRange(
                                  start: _dateFrom!,
                                  end: _dateTo!,
                                )
                                : null,
                        onDateRangeSelected: (picked) {
                          setState(() {
                            _dateFrom = picked.start;
                            _dateTo = DateTime(
                              picked.end.year,
                              picked.end.month,
                              picked.end.day,
                              23,
                              59,
                              59,
                            );
                            _currentPage = 0;
                          });
                        },
                        onClear: () {
                          setState(() {
                            _dateFrom = null;
                            _dateTo = null;
                            _currentPage = 0;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child:
                      isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : movements.isEmpty
                          ? const _EmptyState(
                            icon: Icons.swap_horiz_outlined,
                            message: 'No hay movimientos registrados',
                          )
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
                                    'Mostrando ${movements.isEmpty ? 0 : pageStart + 1}–$pageEnd de ${movements.length} registros',
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
                                        pageItems
                                            .length, // Usamos la lista de la página
                                    separatorBuilder:
                                        (_, __) => const SizedBox(height: 8),
                                    itemBuilder:
                                        (_, i) => _MovementCard(
                                          movement: pageItems[i],
                                        ), // Usamos la lista de la página
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

            // ── NUEVO FAB PARA MOVIMIENTO MANUAL ────────────────
            Positioned(
              bottom: 24,
              right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'fab_movements',
                onPressed: () => _openMovementSheet(),
                backgroundColor: AppColors.primary,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text(
                  'Nuevo movimiento',
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

  String _typeLabel(String t) {
    switch (t) {
      case 'INCOME':
        return 'Ingreso';
      case 'EXPENSE':
        return 'Egreso';
      case 'TRANSFER':
        return 'Transfer.';
      default:
        return 'Todos';
    }
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'INCOME':
        return AppColors.success;
      case 'EXPENSE':
        return AppColors.danger;
      case 'TRANSFER':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }
}

// ── Bottom Sheet: Crear Movimiento Manual ─────────────────────────────────────

class _MovementFormSheet extends StatefulWidget {
  const _MovementFormSheet();

  @override
  State<_MovementFormSheet> createState() => _MovementFormSheetState();
}

class _MovementFormSheetState extends State<_MovementFormSheet> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  String _type = 'INCOME';
  String? _sourceAccountId;
  String? _destAccountId;

  List<FinancialAccountModel> _accounts = [];
  bool _loadingAccounts = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    try {
      final res = await _supabase
          .from('financial_accounts')
          .select('id, name, type, balance, is_active, created_at')
          .eq('is_active', true)
          .order('name');

      if (mounted) {
        setState(() {
          _accounts =
              (res as List)
                  .map(
                    (e) => FinancialAccountModel.fromJson(
                      Map<String, dynamic>.from(e as Map),
                    ),
                  )
                  .toList();
          if (_accounts.isNotEmpty) {
            _sourceAccountId = _accounts.first.id;
            if (_accounts.length > 1) {
              _destAccountId = _accounts[1].id;
            } else {
              _destAccountId = _accounts.first.id;
            }
          }
          _loadingAccounts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error cargando cuentas',
          type: SnackbarType.error,
        );
        setState(() => _loadingAccounts = false);
      }
    }
  }

  Future<String?> _getActiveShift(String accountId) async {
    final res =
        await _supabase
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

      final profileRes =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', user.id)
              .maybeSingle();
      final profileId = profileRes?['id'] as String? ?? user.id;

      final amount =
          double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;

      // Consultar saldo actual de origen
      final sourceAccRes =
          await _supabase
              .from('financial_accounts')
              .select('balance, name')
              .eq('id', _sourceAccountId!)
              .single();
      final currentSourceBalance = (sourceAccRes['balance'] as num).toDouble();
      final sourceName = sourceAccRes['name'] as String;

      // Buscar si origen tiene turno abierto (importante para las cajas)
      final sourceShiftId = await _getActiveShift(_sourceAccountId!);

      if (_type == 'TRANSFER') {
        // Consultar saldo actual de destino
        final destAccRes =
            await _supabase
                .from('financial_accounts')
                .select('balance, name')
                .eq('id', _destAccountId!)
                .single();
        final currentDestBalance = (destAccRes['balance'] as num).toDouble();
        final destName = destAccRes['name'] as String;

        // Buscar si destino tiene turno abierto
        final destShiftId = await _getActiveShift(_destAccountId!);

        // 1. Restar de origen
        await _supabase
            .from('financial_accounts')
            .update({'balance': currentSourceBalance - amount})
            .eq('id', _sourceAccountId!);
        // 2. Sumar a destino
        await _supabase
            .from('financial_accounts')
            .update({'balance': currentDestBalance + amount})
            .eq('id', _destAccountId!);

        // 3. Crear registros cruzados
        await _supabase.from('account_movements').insert([
          {
            'account_id': _sourceAccountId,
            'movement_type': 'EXPENSE',
            'amount': amount,
            'description':
                'Transferencia enviada a $destName${_descCtrl.text.trim().isNotEmpty ? ' — ${_descCtrl.text.trim()}' : ''}',
            'created_by': profileId,
            'shift_id': sourceShiftId,
            'reference_type': 'manual_transfer',
          },
          {
            'account_id': _destAccountId,
            'movement_type': 'INCOME',
            'amount': amount,
            'description':
                'Transferencia recibida de $sourceName${_descCtrl.text.trim().isNotEmpty ? ' — ${_descCtrl.text.trim()}' : ''}',
            'created_by': profileId,
            'shift_id': destShiftId,
            'reference_type': 'manual_transfer',
          },
        ]);
      } else {
        // Es un Ingreso o Egreso Simple
        final isIncome = _type == 'INCOME';
        final newBalance =
            isIncome
                ? (currentSourceBalance + amount)
                : (currentSourceBalance - amount);

        await _supabase
            .from('financial_accounts')
            .update({'balance': newBalance})
            .eq('id', _sourceAccountId!);

        await _supabase.from('account_movements').insert({
          'account_id': _sourceAccountId,
          'movement_type': _type,
          'amount': amount,
          'description':
              _descCtrl.text.trim().isNotEmpty
                  ? _descCtrl.text.trim()
                  : 'Movimiento manual',
          'created_by': profileId,
          'shift_id': sourceShiftId,
          'reference_type': 'manual',
        });
      }

      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Movimiento registrado correctamente',
        type: SnackbarType.success,
      );
      Navigator.pop(context, true);
      return;
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error registrando movimiento: $e',
          type: SnackbarType.error,
        );
      }
    }
    if (mounted) setState(() => _saving = false);
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

    if (_loadingAccounts) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(child: CircularProgressIndicator()),
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
          border: Border.all(color: isSelected ? color : AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: isSelected ? Colors.white : color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
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
  final void Function(String?) onChanged;

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
          icon: const Icon(Icons.expand_more_rounded),
          items:
              accounts.map((a) {
                return DropdownMenuItem<String>(
                  value: a.id,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${a.name} (S/ ${a.balance.toStringAsFixed(2)})',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
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

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES COMPARTIDOS
// ══════════════════════════════════════════════════════════════════════════════

class _MovementCard extends StatelessWidget {
  final AccountMovementModel movement;
  const _MovementCard({required this.movement});

  @override
  Widget build(BuildContext context) {
    final type = movement.movementType;
    final amount = movement.amount;
    final description = movement.description;
    final referenceType = movement.referenceType;
    final createdAt = movement.createdAt;
    final accountName = movement.accountName ?? '–';
    final createdBy = movement.createdByName;

    Color typeColor;
    IconData typeIcon;
    String typeLabel;
    switch (type) {
      case 'INCOME':
        typeColor = AppColors.success;
        typeIcon = Icons.add_circle_rounded;
        typeLabel = 'Ingreso';
        break;
      case 'EXPENSE':
        typeColor = AppColors.danger;
        typeIcon = Icons.remove_circle_rounded;
        typeLabel = 'Egreso';
        break;
      case 'TRANSFER':
        typeColor = AppColors.primary;
        typeIcon = Icons.swap_horiz_rounded;
        typeLabel = 'Transferencia';
        break;
      default:
        typeColor = AppColors.textSecondary;
        typeIcon = Icons.circle_outlined;
        typeLabel = type;
    }

    final dt = createdAt.toLocal();
    final dateLabel =
        '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: typeColor, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(typeIcon, size: 20, color: typeColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    description,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _DetailPill(
                        icon: Icons.account_balance_wallet_rounded,
                        label: accountName,
                        color: typeColor,
                      ),
                      if (referenceType != null && referenceType.isNotEmpty)
                        _DetailPill(
                          icon: Icons.link_rounded,
                          label: referenceType,
                        ),
                      _DetailPill(
                        icon: Icons.schedule_rounded,
                        label: dateLabel,
                      ),
                      _DetailPill(
                        icon: Icons.person_outline_rounded,
                        label: createdBy,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${type == 'EXPENSE' ? '-' : '+'}S/ ${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: typeColor,
                  ),
                ),
                Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: typeColor.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
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

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}

class _AccountDropdown extends StatelessWidget {
  final List<String> accounts;
  final String selected;
  final void Function(String) onChanged;
  const _AccountDropdown({
    required this.accounts,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isDense: true,
          icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
          items:
              accounts
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(
                        c,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _DetailPill({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: c,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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
