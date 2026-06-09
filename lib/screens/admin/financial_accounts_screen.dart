import 'package:flutter/material.dart';
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
          // ── Tab Bar ────────────────────────────────────────────────────
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

          // ── Tab Views ──────────────────────────────────────────────────
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
// TAB 1 — CUENTAS FINANCIERAS
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

        // Resumen
        final totalBalance = accounts
            .where((a) => a['is_active'] == true)
            .fold<double>(0, (s, a) => s + (a['balance'] as num).toDouble());
        final activeCount =
            accounts.where((a) => a['is_active'] == true).length;

        return Column(
          children: [
            // ── Resumen ────────────────────────────────────────────────
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

            // ── Lista ──────────────────────────────────────────────────
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
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: accounts.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder:
                              (_, i) => _AccountCard(account: accounts[i]),
                        ),
                      ),
            ),
          ],
        );
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Map<String, dynamic> account;
  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context) {
    final name = account['name'] as String;
    final type = account['type'] as String;
    final balance = (account['balance'] as num).toDouble();
    final isActive = account['is_active'] as bool? ?? true;

    // Icono y color según tipo de cuenta
    IconData typeIcon;
    Color typeColor;
    switch (type.toUpperCase()) {
      case 'CAJA':
      case 'CASH':
        typeIcon = Icons.point_of_sale_rounded;
        typeColor = AppColors.teal;
        break;
      case 'BANCO':
      case 'BANK':
        typeIcon = Icons.account_balance_rounded;
        typeColor = AppColors.primary;
        break;
      case 'DIGITAL':
      case 'WALLET':
        typeIcon = Icons.phone_android_rounded;
        typeColor = Colors.purple.shade400;
        break;
      default:
        typeIcon = Icons.savings_rounded;
        typeColor = AppColors.textSecondary;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border:
            !isActive
                ? Border.all(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  width: 1,
                )
                : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Icono tipo cuenta
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

            // Info
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Inactiva',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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

            // Balance
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'S/ ${balance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: balance >= 0 ? AppColors.success : AppColors.danger,
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
  String _filterType = 'Todos'; // Todos | INCOME | EXPENSE | TRANSFER
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
        .select('''
          id, movement_type, amount, description, reference_type,
          reference_id, created_at,
          financial_accounts(id, name, type),
          profiles(full_name)
        ''')
        .order('created_at', ascending: false)
        .limit(200);

    final list =
        (response as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

    // Extraer nombres de cuentas para el filtro
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

    if (mounted) {
      setState(() {
        _accountNames = ['Todas', ...names];
      });
    }

    return list;
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> data) {
    return data.where((m) {
      final desc = (m['description'] as String? ?? '').toLowerCase();
      final refType = (m['reference_type'] as String? ?? '').toLowerCase();
      final matchSearch =
          _searchText.isEmpty ||
          desc.contains(_searchText.toLowerCase()) ||
          refType.contains(_searchText.toLowerCase());

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

        // Totales sobre datos filtrados
        final totalIncome = movements
            .where((m) => m['movement_type'] == 'INCOME')
            .fold<double>(0, (s, m) => s + (m['amount'] as num).toDouble());
        final totalExpense = movements
            .where((m) => m['movement_type'] == 'EXPENSE')
            .fold<double>(0, (s, m) => s + (m['amount'] as num).toDouble());

        return Column(
          children: [
            // ── Resumen ────────────────────────────────────────────────
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

            // ── Filtros tipo ───────────────────────────────────────────
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

            // ── Búsqueda + cuenta ──────────────────────────────────────
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

            // ── Lista ──────────────────────────────────────────────────
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

  String _typeLabel(String type) {
    switch (type) {
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

  Color _typeColor(String type) {
    switch (type) {
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
    final accountType =
        (movement['financial_accounts'] as Map<String, dynamic>?)?['type']
            as String? ??
        '';
    final createdBy =
        (movement['profiles'] as Map<String, dynamic>?)?['full_name']
            as String?;

    // Color e icono según tipo
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

    // Formatear fecha
    String dateLabel = '–';
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt)?.toLocal();
      if (dt != null) {
        dateLabel =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
            ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
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
            // Icono tipo
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

            // Descripción + meta
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

            // Monto
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
// TAB 3 — TURNOS DE CAJA (CASH SHIFTS)
// ══════════════════════════════════════════════════════════════════════════════

class _ShiftsTab extends StatefulWidget {
  const _ShiftsTab();

  @override
  State<_ShiftsTab> createState() => _ShiftsTabState();
}

class _ShiftsTabState extends State<_ShiftsTab>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _future;
  String _filterStatus = 'Todos'; // Todos | OPEN | CLOSED

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  void _refresh() => setState(() => _future = _load());

  Future<List<Map<String, dynamic>>> _load() async {
    final response = await _supabase
        .from('cash_shifts')
        .select('''
          id, status, opening_amount, expected_amount, actual_amount,
          difference_amount, notes, opened_at, closed_at,
          financial_accounts(name, type),
          opened_by_profile:profiles!cash_shifts_opened_by_fkey(full_name),
          closed_by_profile:profiles!cash_shifts_closed_by_fkey(full_name)
        ''')
        .order('opened_at', ascending: false)
        .limit(100);

    return (response as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> data) {
    if (_filterStatus == 'Todos') return data;
    return data
        .where((s) => (s['status'] as String?) == _filterStatus)
        .toList();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final allShifts = snapshot.data ?? [];
        final shifts = _applyFilters(allShifts);
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        final openCount = allShifts.where((s) => s['status'] == 'OPEN').length;
        final closedCount =
            allShifts.where((s) => s['status'] == 'CLOSED').length;

        // Turno abierto activo (si existe)
        final openShift =
            allShifts.isNotEmpty && allShifts.first['status'] == 'OPEN'
                ? allShifts.first
                : null;

        return Column(
          children: [
            // ── Estado turno activo ────────────────────────────────────
            if (openShift != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _ActiveShiftBanner(shift: openShift),
              ),

            // ── Filtros estado ─────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                openShift != null ? 10 : 14,
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
                                  _filterStatus == 'OPEN' ? 'Todos' : 'OPEN',
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

            // ── Lista ──────────────────────────────────────────────────
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
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: shifts.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _ShiftCard(shift: shifts[i]),
                        ),
                      ),
            ),
          ],
        );
      },
    );
  }
}

// ── Banner de turno activo ─────────────────────────────────────────────────

class _ActiveShiftBanner extends StatelessWidget {
  final Map<String, dynamic> shift;
  const _ActiveShiftBanner({required this.shift});

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
      if (dt != null) {
        openedLabel =
            '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
            ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
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
            width: 10,
            height: 10,
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
                  'Apertura: S/ ${openingAmount.toStringAsFixed(2)}  ·  $openedBy  ·  $openedLabel',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.success.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card de turno de caja ─────────────────────────────────────────────────

class _ShiftCard extends StatelessWidget {
  final Map<String, dynamic> shift;
  const _ShiftCard({required this.shift});

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

    String _fmtDate(String? s) {
      if (s == null) return '–';
      final dt = DateTime.tryParse(s)?.toLocal();
      if (dt == null) return '–';
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}'
          ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }

    // Duración del turno
    String durationLabel = '';
    if (openedAtStr != null && closedAtStr != null) {
      final open = DateTime.tryParse(openedAtStr);
      final close = DateTime.tryParse(closedAtStr);
      if (open != null && close != null) {
        final diff = close.difference(open);
        final h = diff.inHours;
        final m = diff.inMinutes % 60;
        durationLabel = '${h}h ${m}m';
      }
    }

    final statusColor = isOpen ? AppColors.success : AppColors.textSecondary;

    // Color diferencia
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
          // Header
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isOpen ? 'ABIERTO' : 'CERRADO',
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                letterSpacing: 0.3,
                              ),
                            ),
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

          // Montos
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

          // Footer: fechas + duración + notas
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
                      _fmtDate(openedAtStr),
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
                        _fmtDate(closedAtStr),
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
