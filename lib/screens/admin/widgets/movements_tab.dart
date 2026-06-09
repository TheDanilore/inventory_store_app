

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — MOVIMIENTOS DE CUENTAS
// ══════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:inventory_store_app/models/account_movement_model.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
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

    // CORRECCIÓN: fromJson en lugar de fromMap
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
    // Actualizar _accountNames fuera del async: se hará en el FutureBuilder
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
      return matchSearch && matchType && matchAccount;
    }).toList();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<List<AccountMovementModel>>(
      future: _future,
      builder: (context, snapshot) {
        // Aplicar nombres de cuentas cuando el Future termina (sin setState async)
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
