import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';

// ══════════════════════════════════════════════════════════════════════════════
// FINANCIAL ACCOUNTS SCREEN — Cuentas · Movimientos · Turnos de Caja
// ══════════════════════════════════════════════════════════════════════════════

class FinancialAccountsScreen extends StatefulWidget {
  const FinancialAccountsScreen({super.key});

  @override
  State<FinancialAccountsScreen> createState() =>
      _FinancialAccountsScreenState();
}

class _FinancialAccountsScreenState extends State<FinancialAccountsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Finanzas',
      showBackButton: true,
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.account_balance_wallet_rounded, size: 17),
                  text: 'Cuentas',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: Icon(Icons.swap_horiz_rounded, size: 17),
                  text: 'Movimientos',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
                Tab(
                  icon: Icon(Icons.point_of_sale_rounded, size: 17),
                  text: 'Turnos',
                  iconMargin: EdgeInsets.only(bottom: 2),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [_AccountsTab(), _MovementsTab(), _ShiftsTab()],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — CUENTAS FINANCIERAS  (crear / editar)
// ══════════════════════════════════════════════════════════════════════════════

class _AccountsTab extends StatefulWidget {
  const _AccountsTab();
  @override
  State<_AccountsTab> createState() => _AccountsTabState();
}

class _AccountsTabState extends State<_AccountsTab>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _refresh() => setState(() => _future = _load());

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await _supabase
        .from('financial_accounts')
        .select('id, name, type, balance, is_active, created_at')
        .order('is_active', ascending: false)
        .order('name');
    return (response as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> _openAccountSheet({Map<String, dynamic>? account}) async {
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
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final accounts = snapshot.data ?? [];
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final totalBalance = accounts
            .where((a) => a['is_active'] == true)
            .fold<double>(0, (s, a) => s + (a['balance'] as num).toDouble());
        final activeCount =
            accounts.where((a) => a['is_active'] == true).length;

        return Stack(
          children: [
            Column(
              children: [
                // Resumen
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
            // FAB
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
  final Map<String, dynamic>? account; // null = crear
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
      _nameCtrl.text = widget.account!['name'] as String? ?? '';
      _type = widget.account!['type'] as String? ?? 'CAJA';
      _isActive = widget.account!['is_active'] as bool? ?? true;
      // El balance no se edita directamente en edición (se mueve via movimientos)
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
            .eq('id', widget.account!['id'] as String);
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
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
            // Handle
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

            // Nombre
            _FieldLabel('Nombre de la cuenta'),
            TextFormField(
              controller: _nameCtrl,
              decoration: _inputDeco('Ej: Caja principal'),
              textCapitalization: TextCapitalization.sentences,
              validator:
                  (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 14),

            // Tipo
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

            // Balance inicial (solo en creación)
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

            // Activo (solo en edición)
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

            // Botón guardar
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

Widget _FieldLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
  ),
);

// ── Card de cuenta ───────────────────────────────────────────────────────────

class _AccountCard extends StatelessWidget {
  final Map<String, dynamic> account;
  final VoidCallback onTap;
  const _AccountCard({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = account['name'] as String;
    final type = account['type'] as String;
    final balance = (account['balance'] as num).toDouble();
    final isActive = account['is_active'] as bool? ?? true;

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
                          _Badge(
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
                  Text(
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

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — MOVIMIENTOS DE CUENTAS
// ══════════════════════════════════════════════════════════════════════════════

class _MovementsTab extends StatefulWidget {
  const _MovementsTab();
  @override
  State<_MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends State<_MovementsTab>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;
  String _filterType = 'Todos';
  String _filterAccount = 'Todas';
  List<String> _accountNames = ['Todas'];
  final _searchCtrl = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _refresh() => setState(() => _future = _load());

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await _supabase
        .from('account_movements')
        .select(
          'id, movement_type, amount, description, reference_type, reference_id, created_at, financial_accounts(id, name, type), profiles(full_name)',
        )
        .order('created_at', ascending: false)
        .limit(200);

    final list =
        (response as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    final names =
        list
            .map(
              (m) =>
                  (m['financial_accounts'] as Map<String, dynamic>?)?['name']
                      as String? ??
                  '–',
            )
            .toSet()
            .toList()
          ..sort();
    if (mounted) setState(() => _accountNames = ['Todas', ...names]);

    return list;
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> data) {
    return data.where((m) {
      final desc = (m['description'] as String? ?? '').toLowerCase();
      final matchSearch =
          _searchText.isEmpty || desc.contains(_searchText.toLowerCase());
      final type = m['movement_type'] as String? ?? '';
      final matchType = _filterType == 'Todos' || type == _filterType;
      final accName =
          (m['financial_accounts'] as Map<String, dynamic>?)?['name']
              as String? ??
          '–';
      final matchAccount =
          _filterAccount == 'Todas' || accName == _filterAccount;
      return matchSearch && matchType && matchAccount;
    }).toList();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final allMovements = snapshot.data ?? [];
        final movements = _applyFilters(allMovements);
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final totalIncome = movements
            .where((m) => m['movement_type'] == 'INCOME')
            .fold<double>(0, (s, m) => s + (m['amount'] as num).toDouble());
        final totalExpense = movements
            .where((m) => m['movement_type'] == 'EXPENSE')
            .fold<double>(0, (s, m) => s + (m['amount'] as num).toDouble());

        return Column(
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
                  for (final t in ['Todos', 'INCOME', 'EXPENSE', 'TRANSFER'])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _FilterChip(
                        label: _typeLabel(t),
                        color: _typeColor(t),
                        selected: _filterType == t,
                        onTap:
                            () => setState(
                              () =>
                                  _filterType = _filterType == t ? 'Todos' : t,
                            ),
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
                      onChanged: (v) => setState(() => _searchText = v),
                      decoration: InputDecoration(
                        hintText: 'Buscar descripción...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        suffixIcon:
                            _searchText.isNotEmpty
                                ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchText = '');
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
                    onChanged: (v) => setState(() => _filterAccount = v),
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
                      : RefreshIndicator(
                        onRefresh: () async => _refresh(),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: movements.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder:
                              (_, i) => _MovementCard(movement: movements[i]),
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

class _MovementCard extends StatelessWidget {
  final Map<String, dynamic> movement;
  const _MovementCard({required this.movement});

  @override
  Widget build(BuildContext context) {
    final type = movement['movement_type'] as String? ?? '';
    final amount = (movement['amount'] as num).toDouble();
    final description = movement['description'] as String? ?? '–';
    final referenceType = movement['reference_type'] as String?;
    final createdAt = movement['created_at'] as String?;
    final accountName =
        (movement['financial_accounts'] as Map<String, dynamic>?)?['name']
            as String? ??
        '–';
    final createdBy =
        (movement['profiles'] as Map<String, dynamic>?)?['full_name']
            as String?;

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

    String dateLabel = '–';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt)?.toLocal();
      if (dt != null)
        dateLabel =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

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
                      if (createdBy != null)
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

// ══════════════════════════════════════════════════════════════════════════════
// TAB 3 — TURNOS DE CAJA  (abrir / cerrar)
// ══════════════════════════════════════════════════════════════════════════════

class _ShiftsTab extends StatefulWidget {
  const _ShiftsTab();
  @override
  State<_ShiftsTab> createState() => _ShiftsTabState();
}

class _ShiftsTabState extends State<_ShiftsTab>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  late Future<_ShiftsData> _future;
  String _filterStatus = 'Todos';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _refresh() => setState(() => _future = _load());

  Future<_ShiftsData> _load() async {
    // Turnos
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

    final shifts =
        (shiftsRes as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    // Cuentas activas (para el selector al abrir turno)
    final accountsRes = await _supabase
        .from('financial_accounts')
        .select('id, name, type')
        .eq('is_active', true)
        .order('name');

    final accounts =
        (accountsRes as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    // IDs de cuentas con turno abierto actualmente
    final openAccountIds =
        shifts
            .where((s) => s['status'] == 'OPEN')
            .map((s) => s['account_id'] as String)
            .toSet();

    return _ShiftsData(
      shifts: shifts,
      accounts: accounts,
      openAccountIds: openAccountIds,
    );
  }

  // Calcular el monto esperado al cerrar:
  // opening_amount + suma de movimientos INCOME del turno - suma EXPENSE
  Future<double> _calcExpected(
    String shiftId,
    String accountId,
    double openingAmount,
    String openedAt,
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
    List<Map<String, dynamic>> accounts,
    Set<String> openAccountIds,
  ) async {
    final availableAccounts =
        accounts
            .where((a) => !openAccountIds.contains(a['id'] as String))
            .toList();
    if (availableAccounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Todas las cuentas ya tienen un turno abierto'),
          backgroundColor: AppColors.warning,
        ),
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

  Future<void> _openCloseShiftSheet(Map<String, dynamic> shift) async {
    final openingAmount = (shift['opening_amount'] as num).toDouble();
    final openedAt = shift['opened_at'] as String;
    final accountId = shift['account_id'] as String;
    final shiftId = shift['id'] as String;

    final expected = await _calcExpected(
      shiftId,
      accountId,
      openingAmount,
      openedAt,
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

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> shifts) {
    if (_filterStatus == 'Todos') return shifts;
    return shifts.where((s) => s['status'] == _filterStatus).toList();
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

        final openCount = allShifts.where((s) => s['status'] == 'OPEN').length;
        final closedCount =
            allShifts.where((s) => s['status'] == 'CLOSED').length;

        // Turnos abiertos (puede haber uno por cuenta)
        final openShifts =
            allShifts.where((s) => s['status'] == 'OPEN').toList();

        return Stack(
          children: [
            Column(
              children: [
                // Banners de turnos abiertos
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

                // Filtros
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
                            () => setState(
                              () =>
                                  _filterStatus =
                                      _filterStatus == 'OPEN'
                                          ? 'Todos'
                                          : 'OPEN',
                            ),
                      ),
                      const SizedBox(width: 6),
                      _StatusChip(
                        label: 'Cerrados',
                        count: closedCount,
                        color: AppColors.textSecondary,
                        selected: _filterStatus == 'CLOSED',
                        onTap:
                            () => setState(
                              () =>
                                  _filterStatus =
                                      _filterStatus == 'CLOSED'
                                          ? 'Todos'
                                          : 'CLOSED',
                            ),
                      ),
                      const Spacer(),
                      Text(
                        '${shifts.length} turno${shifts.length != 1 ? 's' : ''}',
                        style: TextStyle(
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
                          : RefreshIndicator(
                            onRefresh: () async => _refresh(),
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                              itemCount: shifts.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(height: 8),
                              itemBuilder:
                                  (_, i) => _ShiftCard(
                                    shift: shifts[i],
                                    onClose:
                                        shifts[i]['status'] == 'OPEN'
                                            ? () =>
                                                _openCloseShiftSheet(shifts[i])
                                            : null,
                                  ),
                            ),
                          ),
                ),
              ],
            ),

            // FAB — Abrir nuevo turno
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

// ── Data holder ──────────────────────────────────────────────────────────────

class _ShiftsData {
  final List<Map<String, dynamic>> shifts;
  final List<Map<String, dynamic>> accounts;
  final Set<String> openAccountIds;
  const _ShiftsData({
    required this.shifts,
    required this.accounts,
    required this.openAccountIds,
  });
}

// ── Bottom Sheet: Abrir turno ─────────────────────────────────────────────────

class _OpenShiftSheet extends StatefulWidget {
  final List<Map<String, dynamic>> accounts;
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
      _selectedAccountId = widget.accounts.first['id'] as String;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedAccountId == null)
      return;
    setState(() => _saving = true);

    try {
      final user = _supabase.auth.currentUser;
      // Obtener el profile_id del usuario actual
      final profileRes =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', user!.id)
              .single();
      final profileId = profileRes['id'] as String;

      final amount =
          double.tryParse(_amountCtrl.text.replaceAll(',', '.')) ?? 0.0;

      await _supabase.from('cash_shifts').insert({
        'account_id': _selectedAccountId,
        'opened_by': profileId,
        'opening_amount': amount,
        'status': 'OPEN',
        'opened_at': DateTime.now().toUtc().toIso8601String(),
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir turno: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
                  child: Icon(
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
                              value: a['id'] as String,
                              child: Row(
                                children: [
                                  Icon(
                                    _accountTypeIcon(
                                      a['type'] as String? ?? '',
                                    ),
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    a['name'] as String,
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
                if (double.tryParse(v.replaceAll(',', '.')) == null)
                  return 'Monto inválido';
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
  final Map<String, dynamic> shift;
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
      final profileRes =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', user!.id)
              .single();
      final profileId = profileRes['id'] as String;

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
          .eq('id', widget.shift['id'] as String);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar turno: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final accountName =
        (widget.shift['financial_accounts'] as Map<String, dynamic>?)?['name']
            as String? ??
        '–';
    final openingAmount = (widget.shift['opening_amount'] as num).toDouble();

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
                  child: Icon(
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
                        style: TextStyle(
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

            // Resumen apertura + esperado
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _AmountTile(
                      label: 'Apertura',
                      value: 'S/ ${openingAmount.toStringAsFixed(2)}',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _AmountTile(
                      label: 'Esperado',
                      value: 'S/ ${widget.expectedAmount.toStringAsFixed(2)}',
                      color: AppColors.primary,
                    ),
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
                if (double.tryParse(v.replaceAll(',', '.')) == null)
                  return 'Monto inválido';
                return null;
              },
            ),

            // Diferencia en tiempo real
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
  final Map<String, dynamic> shift;
  final VoidCallback onClose;
  const _ActiveShiftBanner({required this.shift, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final accountName =
        (shift['financial_accounts'] as Map<String, dynamic>?)?['name']
            as String? ??
        '–';
    final openedBy =
        (shift['opened_by_profile'] as Map<String, dynamic>?)?['full_name']
            as String? ??
        '–';
    final openingAmount = (shift['opening_amount'] as num?)?.toDouble() ?? 0.0;
    final openedAtStr = shift['opened_at'] as String?;

    String openedLabel = '–';
    if (openedAtStr != null) {
      final dt = DateTime.tryParse(openedAtStr)?.toLocal();
      if (dt != null)
        openedLabel =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

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
            decoration: BoxDecoration(
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
                  style: TextStyle(
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
            icon: Icon(Icons.lock_rounded, size: 14, color: AppColors.danger),
            label: Text(
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
  final Map<String, dynamic> shift;
  final VoidCallback? onClose;
  const _ShiftCard({required this.shift, this.onClose});

  @override
  Widget build(BuildContext context) {
    final status = shift['status'] as String? ?? 'CLOSED';
    final isOpen = status == 'OPEN';
    final accountName =
        (shift['financial_accounts'] as Map<String, dynamic>?)?['name']
            as String? ??
        '–';
    final openedBy =
        (shift['opened_by_profile'] as Map<String, dynamic>?)?['full_name']
            as String? ??
        '–';
    final closedBy =
        (shift['closed_by_profile'] as Map<String, dynamic>?)?['full_name']
            as String?;
    final openingAmount = (shift['opening_amount'] as num?)?.toDouble() ?? 0.0;
    final expectedAmount = (shift['expected_amount'] as num?)?.toDouble();
    final actualAmount = (shift['actual_amount'] as num?)?.toDouble();
    final differenceAmount = (shift['difference_amount'] as num?)?.toDouble();
    final notes = shift['notes'] as String?;
    final openedAtStr = shift['opened_at'] as String?;
    final closedAtStr = shift['closed_at'] as String?;

    String fmtDate(String? s) {
      if (s == null) return '–';
      final dt = DateTime.tryParse(s)?.toLocal();
      if (dt == null) return '–';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    String durationLabel = '';
    if (openedAtStr != null && closedAtStr != null) {
      final open = DateTime.tryParse(openedAtStr);
      final close = DateTime.tryParse(closedAtStr);
      if (open != null && close != null) {
        final diff = close.difference(open);
        durationLabel = '${diff.inHours}h ${diff.inMinutes % 60}m';
      }
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
                        style: TextStyle(
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
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(14),
                bottomRight: Radius.circular(14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.login_rounded,
                      size: 12,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      fmtDate(openedAtStr),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (closedAtStr != null) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.logout_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        fmtDate(closedAtStr),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (durationLabel.isNotEmpty) ...[
                      const Spacer(),
                      Icon(
                        Icons.timer_outlined,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        durationLabel,
                        style: TextStyle(
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
                      Icon(
                        Icons.person_outline_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Cerrado por $closedBy',
                        style: TextStyle(
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
                      Icon(
                        Icons.notes_rounded,
                        size: 12,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          notes,
                          style: TextStyle(
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
                      icon: Icon(
                        Icons.lock_rounded,
                        size: 14,
                        color: AppColors.danger,
                      ),
                      label: Text(
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

// ══════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES COMPARTIDOS
// ══════════════════════════════════════════════════════════════════════════════

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
            style: TextStyle(
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
