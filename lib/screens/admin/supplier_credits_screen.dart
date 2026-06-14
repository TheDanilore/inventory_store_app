import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:inventory_store_app/screens/admin/supplier_credit_movements_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/screens/admin/widgets/admin_page_blocks.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';
import 'package:intl/intl.dart';

// ─── MODELO LOCAL ─────────────────────────────────────────────────────────────

class SupplierCreditModel {
  final String creditId;
  final String supplierId;
  final String supplierName;
  final String? supplierTaxId;
  final String? supplierPhone;
  final double creditLimit;
  final double currentDebt;
  final bool isActive;

  double get availableCredit =>
      (creditLimit - currentDebt).clamp(0.0, double.infinity);
  double get usagePercent =>
      creditLimit > 0 ? (currentDebt / creditLimit).clamp(0.0, 1.0) : 0.0;
  bool get isMaxedOut => currentDebt >= creditLimit && creditLimit > 0;

  SupplierCreditModel({
    required this.creditId,
    required this.supplierId,
    required this.supplierName,
    this.supplierTaxId,
    this.supplierPhone,
    required this.creditLimit,
    required this.currentDebt,
    required this.isActive,
  });

  factory SupplierCreditModel.fromJoin(Map<String, dynamic> json) {
    final supplier = json['suppliers'] as Map<String, dynamic>? ?? {};
    return SupplierCreditModel(
      creditId: json['id'] as String,
      supplierId: json['supplier_id'] as String,
      supplierName: supplier['name'] as String? ?? 'Proveedor desconocido',
      supplierTaxId: supplier['tax_id'] as String?,
      supplierPhone: supplier['phone'] as String?,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      currentDebt: (json['current_debt'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? false,
    );
  }
}

// ─── PANTALLA PRINCIPAL ───────────────────────────────────────────────────────

class SupplierCreditsScreen extends StatefulWidget {
  const SupplierCreditsScreen({super.key});

  @override
  State<SupplierCreditsScreen> createState() => _SupplierCreditsScreenState();
}

class _SupplierCreditsScreenState extends State<SupplierCreditsScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  late final TabController _tabCtrl;

  List<SupplierCreditModel> _all = [];
  List<SupplierCreditModel> _filtered = [];
  bool _isLoading = true;

  // Paginación
  static const int _pageSize = 8;
  int _currentPage = 0;

  // Stats globales
  double _totalDebt = 0;
  int _activeAccounts = 0;
  int _suspendedAccounts = 0;
  int _maxedOutAccounts = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _fetchAccounts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAccounts() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('supplier_credits')
          .select('*, suppliers(name, tax_id, phone)')
          .order('current_debt', ascending: false);

      final accounts =
          (response as List)
              .map((item) => SupplierCreditModel.fromJoin(item))
              .toList();

      double debt = 0;
      int active = 0;
      int suspended = 0;
      int maxed = 0;
      for (final a in accounts) {
        debt += a.currentDebt;
        if (a.isActive) {
          active++;
          if (a.isMaxedOut) maxed++;
        } else {
          suspended++;
        }
      }

      if (mounted) {
        setState(() {
          _all = accounts;
          _applyFilter(_searchCtrl.text);
          _totalDebt = debt;
          _activeAccounts = active;
          _suspendedAccounts = suspended;
          _maxedOutAccounts = maxed;
        });
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error al cargar créditos: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter(String query) {
    final term = query.trim().toLowerCase();
    List<SupplierCreditModel> list;
    if (term.isEmpty) {
      list = List.from(_all);
    } else {
      list =
          _all.where((a) {
            return a.supplierName.toLowerCase().contains(term) ||
                (a.supplierTaxId?.contains(term) ?? false) ||
                (a.supplierPhone?.contains(term) ?? false);
          }).toList();
    }
    if (_tabCtrl.index == 1) {
      list = list.where((a) => a.currentDebt > 0 && a.isActive).toList();
    }
    _filtered = list;
    _currentPage = 0;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _applyFilter(query));
    });
  }

  void _openAccountOptions(SupplierCreditModel account) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            account.supplierName.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                account.supplierName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Deuda: S/ ${account.currentDebt.toStringAsFixed(2)} · Límite: S/ ${account.creditLimit.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20),

                  ListTile(
                    leading: const Icon(
                      Icons.history_rounded,
                      color: Colors.blue,
                    ),
                    title: const Text('Ver historial de movimientos'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => SupplierCreditMovementsScreen(
                                creditId: account.creditId,
                                supplierName: account.supplierName,
                                currentDebt: account.currentDebt,
                                creditLimit: account.creditLimit,
                              ),
                        ),
                      ).then((_) => _fetchAccounts());
                    },
                  ),

                  if (account.isActive && account.currentDebt > 0)
                    ListTile(
                      leading: const Icon(
                        Icons.payments_rounded,
                        color: AppColors.success,
                      ),
                      title: const Text('Pagar al proveedor (Amortizar)'),
                      onTap: () {
                        Navigator.pop(ctx);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder:
                              (_) => _SupplierPaymentModal(
                                account: account,
                                onPaymentSaved: _fetchAccounts,
                              ),
                        );
                      },
                    ),

                  ListTile(
                    leading: const Icon(Icons.edit_rounded, color: Colors.blue),
                    title: const Text('Editar línea de crédito'),
                    onTap: () {
                      Navigator.pop(ctx);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder:
                            (_) => _SupplierCreditAccountModal(
                              accountToEdit: account,
                              onSaved: _fetchAccounts,
                            ),
                      );
                    },
                  ),

                  ListTile(
                    leading: Icon(
                      account.isActive
                          ? Icons.block_rounded
                          : Icons.check_circle_rounded,
                      color:
                          account.isActive
                              ? AppColors.danger
                              : AppColors.success,
                    ),
                    title: Text(
                      account.isActive
                          ? 'Suspender crédito'
                          : 'Reactivar crédito',
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _toggleAccountStatus(account);
                    },
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _toggleAccountStatus(SupplierCreditModel account) async {
    try {
      await _supabase
          .from('supplier_credits')
          .update({
            'is_active': !account.isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', account.creditId);

      _fetchAccounts();
      if (mounted) {
        AppSnackbar.show(
          context,
          message:
              account.isActive ? 'Crédito suspendido.' : 'Crédito reactivado.',
          type: SnackbarType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error: $e',
          type: SnackbarType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPages =
        _filtered.isEmpty ? 1 : (_filtered.length / _pageSize).ceil();
    final safePage = _currentPage >= totalPages ? 0 : _currentPage;
    final pageStart = safePage * _pageSize;
    final pageEnd = (pageStart + _pageSize).clamp(0, _filtered.length);
    final pageItems = _filtered.sublist(
      _filtered.isEmpty ? 0 : pageStart,
      _filtered.isEmpty ? 0 : pageEnd,
    );

    return AdminLayout(
      title: 'Cuentas por Pagar',
      showBackButton: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder:
                  (_) => _SupplierCreditAccountModal(onSaved: _fetchAccounts),
            ),
        backgroundColor: Colors.blue.shade700,
        icon: const Icon(Icons.domain_add_rounded, color: Colors.white),
        label: const Text(
          'Nuevo Crédito',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          if (!_isLoading)
            _GlobalStatsBar(
              totalDebt: _totalDebt,
              activeAccounts: _activeAccounts,
              suspendedAccounts: _suspendedAccounts,
              maxedOutAccounts: _maxedOutAccounts,
            ),

          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o RUC...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textMuted,
                    ),
                    filled: true,
                    fillColor: AppColors.bg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabCtrl,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textMuted,
                    indicator: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.all(4),
                    onTap:
                        (_) => setState(() => _applyFilter(_searchCtrl.text)),
                    tabs: [
                      const Tab(text: 'Todas'),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Por Pagar'),
                            if (_all.any(
                              (a) => a.currentDebt > 0 && a.isActive,
                            )) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_all.where((a) => a.currentDebt > 0 && a.isActive).length}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),

          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filtered.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            size: 60,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _tabCtrl.index == 1
                                ? 'No hay deudas con proveedores'
                                : 'No hay proveedores con crédito',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _fetchAccounts,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        itemCount: pageItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final account = pageItems[index];
                          return _SupplierCreditCard(
                            account: account,
                            onTap: () => _openAccountOptions(account),
                          );
                        },
                      ),
                    ),
          ),

          if (!_isLoading && totalPages > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: AdminPageBlocks(
                currentPage: _currentPage,
                totalPages: totalPages,
                onPageChanged: (page) => setState(() => _currentPage = page),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── WIDGETS AUXILIARES ────────────────────────────────────────────────────────

class _GlobalStatsBar extends StatelessWidget {
  final double totalDebt;
  final int activeAccounts;
  final int suspendedAccounts;
  final int maxedOutAccounts;

  const _GlobalStatsBar({
    required this.totalDebt,
    required this.activeAccounts,
    required this.suspendedAccounts,
    required this.maxedOutAccounts,
  });

  String _compact(double v) =>
      v >= 1000
          ? 'S/ ${(v / 1000).toStringAsFixed(1)}K'
          : 'S/ ${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatItem(
            icon: Icons.storefront_rounded,
            value: '$activeAccounts',
            label: 'Activos',
          ),
          Container(height: 36, width: 1, color: Colors.white24),
          _StatItem(
            icon: Icons.warning_amber_rounded,
            value: '$maxedOutAccounts',
            label: 'Al límite',
            valueColor:
                maxedOutAccounts > 0 ? Colors.orange.shade200 : Colors.white,
          ),
          Container(height: 36, width: 1, color: Colors.white24),
          _StatItem(
            icon: Icons.account_balance_rounded,
            value: _compact(totalDebt),
            label: 'Por Pagar',
            valueColor: totalDebt > 0 ? Colors.orange.shade200 : Colors.white,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color? valueColor;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SupplierCreditCard extends StatelessWidget {
  final SupplierCreditModel account;
  final VoidCallback onTap;

  const _SupplierCreditCard({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = account.usagePercent;
    final barColor =
        account.isMaxedOut
            ? AppColors.danger
            : (pct >= 0.8 ? Colors.orange : Colors.blue.shade600);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color:
              account.isMaxedOut
                  ? AppColors.danger.withValues(alpha: 0.4)
                  : AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        account.isActive
                            ? Colors.blue.shade50
                            : Colors.grey.shade200,
                    child: Text(
                      account.supplierName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color:
                            account.isActive
                                ? Colors.blue.shade800
                                : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.supplierName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (account.supplierTaxId != null)
                          Text(
                            'RUC: ${account.supplierTaxId}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Por pagar',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        'S/ ${account.currentDebt.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color:
                              account.currentDebt > 0
                                  ? AppColors.danger
                                  : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Disponible: S/ ${account.availableCredit.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color:
                              account.isActive
                                  ? Colors.blue.shade700
                                  : AppColors.textMuted,
                        ),
                      ),
                      Text(
                        'Límite: S/ ${account.creditLimit.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: AppColors.bg,
                  color: barColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── MODAL: Crear o Editar Línea de Crédito a Proveedor ─────────────────────

class _SupplierCreditAccountModal extends StatefulWidget {
  final VoidCallback onSaved;
  final SupplierCreditModel? accountToEdit;
  const _SupplierCreditAccountModal({
    required this.onSaved,
    this.accountToEdit,
  });
  @override
  State<_SupplierCreditAccountModal> createState() =>
      _SupplierCreditAccountModalState();
}

class _SupplierCreditAccountModalState
    extends State<_SupplierCreditAccountModal> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  Timer? _debounce;
  bool _isSearching = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _matches = [];
  String? _selectedSupplierId;
  String? _selectedSupplierName;
  bool get _isEditing => widget.accountToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _selectedSupplierId = widget.accountToEdit!.supplierId;
      _selectedSupplierName = widget.accountToEdit!.supplierName;
      _searchCtrl.text = _selectedSupplierName!;
      _limitCtrl.text = widget.accountToEdit!.creditLimit.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _limitCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_selectedSupplierId != null) {
      setState(() {
        _selectedSupplierId = null;
        _selectedSupplierName = null;
      });
    }
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _searchSuppliers(query),
    );
  }

  Future<void> _searchSuppliers(String query) async {
    final text = query.trim();
    if (text.isEmpty) {
      setState(() {
        _matches = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final existingCredits = await _supabase
          .from('supplier_credits')
          .select('supplier_id');
      final existingIds =
          (existingCredits as List)
              .map((e) => e['supplier_id'] as String)
              .where(
                (id) =>
                    id !=
                    (_isEditing ? widget.accountToEdit!.supplierId : null),
              )
              .toSet();

      final response = await _supabase
          .from('suppliers')
          .select('id, name, tax_id')
          .eq('is_active', true)
          .or('name.ilike.%$text%,tax_id.ilike.%$text%')
          .limit(20);
      final filtered =
          (response as List)
              .cast<Map<String, dynamic>>()
              .where((p) => !existingIds.contains(p['id'] as String))
              .take(6)
              .toList();

      if (mounted) {
        setState(() {
          _matches = filtered;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSupplier(Map<String, dynamic> supplier) {
    setState(() {
      _selectedSupplierId = supplier['id'] as String;
      _selectedSupplierName = supplier['name'] as String;
      _searchCtrl.text = _selectedSupplierName!;
      _matches = [];
      FocusScope.of(context).unfocus();
    });
  }

  Future<void> _saveAccount() async {
    if (_selectedSupplierId == null || _limitCtrl.text.isEmpty) return;
    final limitVal = double.tryParse(_limitCtrl.text.trim()) ?? 0.0;
    if (_isEditing && limitVal < widget.accountToEdit!.currentDebt) {
      AppSnackbar.show(
        context,
        message: 'El límite no puede ser menor a la deuda.',
        type: SnackbarType.error,
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final authUserId = _supabase.auth.currentUser?.id;
      String? adminProfileId;
      if (authUserId != null) {
        final adminResp =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', authUserId)
                .maybeSingle();
        if (adminResp != null) adminProfileId = adminResp['id'] as String;
      }

      if (_isEditing) {
        await _supabase
            .from('supplier_credits')
            .update({
              'credit_limit': limitVal,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', widget.accountToEdit!.creditId);
      } else {
        await _supabase.from('supplier_credits').insert({
          'supplier_id': _selectedSupplierId,
          'credit_limit': limitVal,
          'current_debt': 0.0,
          'is_active': true,
          'created_by': adminProfileId,
        });
      }
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Crédito guardado.',
          type: SnackbarType.success,
        );
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            _isEditing
                ? 'Editar línea de crédito'
                : 'Nuevo Crédito de Proveedor',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: _isEditing ? Colors.grey.shade100 : AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _selectedSupplierId != null
                        ? Colors.blue
                        : AppColors.border,
              ),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              enabled: !_isEditing,
              decoration: InputDecoration(
                hintText: 'Buscar proveedor...',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color:
                      _selectedSupplierId != null
                          ? Colors.blue
                          : AppColors.textMuted,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_matches.isNotEmpty && _selectedSupplierId == null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _matches.length,
                itemBuilder:
                    (c, i) => ListTile(
                      title: Text(_matches[i]['name']),
                      subtitle: Text('RUC: ${_matches[i]['tax_id'] ?? '-'}'),
                      onTap: () => _selectSupplier(_matches[i]),
                    ),
              ),
            ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _limitCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                hintText: 'Límite (Ej. 5000.00)',
                prefixIcon: Icon(Icons.attach_money_rounded),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child:
                _isSaving
                    ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                    : const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ─── MODAL: Pagar a Proveedor (Amortizar Deuda) ─────────────────────────────

class _FinancialAccountOption {
  final String id;
  final String name;
  final String type;
  final double balance;
  _FinancialAccountOption({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
  });
  String get paymentMethodLabel => name;
}

class _SupplierPaymentModal extends StatefulWidget {
  final SupplierCreditModel account;
  final VoidCallback onPaymentSaved;
  const _SupplierPaymentModal({
    required this.account,
    required this.onPaymentSaved,
  });
  @override
  State<_SupplierPaymentModal> createState() => _SupplierPaymentModalState();
}

class _SupplierPaymentModalState extends State<_SupplierPaymentModal> {
  final _supabase = Supabase.instance.client;
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _isSaving = false;

  List<Map<String, dynamic>> _pendingOrders = [];
  bool _loadingOrders = true;
  String? _selectedOrderId;
  String? _errorMessage;

  List<_FinancialAccountOption> _accounts = [];
  _FinancialAccountOption? _selectedAccount;
  bool _loadingAccounts = true;
  Map<String, dynamic>? _activeShift;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadPendingOrders(), _loadAccounts()]);
  }

  Future<void> _loadPendingOrders() async {
    try {
      final resp = await _supabase
          .from('purchase_orders')
          .select('id, total_amount, amount_paid, payment_status, created_at')
          .eq('supplier_id', widget.account.supplierId)
          .eq('payment_method', 'CREDITO')
          .inFilter('payment_status', ['PENDING', 'PARTIAL'])
          .inFilter('status', ['SENT', 'PARTIAL', 'RECEIVED'])
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _pendingOrders = List<Map<String, dynamic>>.from(resp);
          _loadingOrders = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  Future<void> _loadAccounts() async {
    try {
      final resp = await _supabase
          .from('financial_accounts')
          .select('id, name, type, balance')
          .eq('is_active', true)
          .order('name');
      if (mounted) {
        final accounts =
            (resp as List)
                .map(
                  (a) => _FinancialAccountOption(
                    id: a['id'],
                    name: a['name'],
                    type: a['type'],
                    balance: (a['balance'] as num).toDouble(),
                  ),
                )
                .toList();
        setState(() {
          _accounts = accounts;
          if (accounts.isNotEmpty) _selectedAccount = accounts.first;
          _loadingAccounts = false;
        });
        if (_selectedAccount?.type == 'CAJA') {
          await _checkActiveShift(_selectedAccount!.id);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  Future<void> _checkActiveShift(String accountId) async {
    try {
      final resp =
          await _supabase
              .from('cash_shifts')
              .select('id')
              .eq('account_id', accountId)
              .eq('status', 'OPEN')
              .maybeSingle();
      if (mounted) setState(() => _activeShift = resp);
    } catch (_) {
      if (mounted) setState(() => _activeShift = null);
    }
  }

  num _pendingOf(Map<String, dynamic> order) {
    return ((order['total_amount'] as num) - (order['amount_paid'] as num))
        .clamp(0.0, double.infinity);
  }

  void _validarEntrada(String value) {
    if (value.trim().isEmpty) {
      setState(() => _errorMessage = null);
      return;
    }
    final amount = double.tryParse(value.trim());
    if (amount == null || amount <= 0) {
      setState(() => _errorMessage = 'Número inválido');
      return;
    }

    if (_selectedOrderId != null) {
      final target = _pendingOrders.firstWhere(
        (o) => o['id'] == _selectedOrderId,
      );
      if (amount > _pendingOf(target)) {
        setState(
          () =>
              _errorMessage =
                  'Máx: S/ ${_pendingOf(target).toStringAsFixed(2)}',
        );
        return;
      }
    } else if (amount > widget.account.currentDebt) {
      setState(
        () =>
            _errorMessage =
                'Supera la deuda (S/ ${widget.account.currentDebt.toStringAsFixed(2)})',
      );
      return;
    }

    if (_selectedAccount != null && amount > _selectedAccount!.balance) {
      setState(() => _errorMessage = 'Saldo en cuenta insuficiente');
      return;
    }

    setState(() => _errorMessage = null);
  }

  Future<void> _savePayment() async {
    if (_errorMessage != null ||
        _amountCtrl.text.isEmpty ||
        _selectedAccount == null) {
      return;
    }
    if (_selectedAccount!.type == 'CAJA' && _activeShift == null) {
      AppSnackbar.show(
        context,
        message: 'La caja seleccionada no tiene turno abierto.',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isSaving = true);
    final amount = double.parse(_amountCtrl.text.trim());

    try {
      final authUserId = _supabase.auth.currentUser?.id;
      String? adminProfileId;
      if (authUserId != null) {
        final resp =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', authUserId)
                .maybeSingle();
        if (resp != null) adminProfileId = resp['id'] as String;
      }

      // 1. Pago en proveedor (supplier_credit_movements)
      await _supabase.from('supplier_credit_movements').insert({
        'supplier_credit_id': widget.account.creditId,
        if (_selectedOrderId != null) 'purchase_order_id': _selectedOrderId,
        'movement_type': 'PAYMENT',
        'amount': amount,
        'payment_method': _selectedAccount!.paymentMethodLabel,
        'notes':
            _notesCtrl.text.trim().isEmpty
                ? "Pago a proveedor"
                : _notesCtrl.text.trim(),
        if (adminProfileId != null) 'created_by': adminProfileId,
      });

      // 2. Aplicar a órdenes de compra pendientes (FIFO o Específico)
      final ordersToApply =
          _selectedOrderId != null
              ? _pendingOrders
                  .where((o) => o['id'] == _selectedOrderId)
                  .toList()
              : List<Map<String, dynamic>>.from(_pendingOrders);
      double remaining = amount;
      for (final order in ordersToApply) {
        if (remaining <= 0) break;
        final pending = _pendingOf(order);
        final toApply = remaining >= pending ? pending : remaining;
        final newPaid = (order['amount_paid'] as num).toDouble() + toApply;
        remaining -= toApply;
        await _supabase
            .from('purchase_orders')
            .update({
              'amount_paid': newPaid,
              'payment_status':
                  newPaid >= (order['total_amount'] as num)
                      ? 'PAID'
                      : 'PARTIAL',
            })
            .eq('id', order['id']);
      }

      // 3. Reducir deuda
      await _supabase
          .from('supplier_credits')
          .update({
            'current_debt': (widget.account.currentDebt - amount).clamp(
              0.0,
              double.infinity,
            ),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.account.creditId);

      // 4. EGRESO Financiero (Sale dinero de tu caja/banco para pagar al proveedor)
      await _supabase.from('account_movements').insert({
        'account_id': _selectedAccount!.id,
        'movement_type': 'EXPENSE',
        'amount': amount,
        'description': 'Pago a proveedor — ${widget.account.supplierName}',
        'reference_type': 'supplier_credits',
        'reference_id': widget.account.creditId,
        if (_selectedAccount!.type == 'CAJA' && _activeShift != null)
          'shift_id': _activeShift!['id'],
        if (adminProfileId != null) 'created_by': adminProfileId,
      });

      // 5. Reducir balance de la cuenta financiera
      await _supabase
          .from('financial_accounts')
          .update({'balance': _selectedAccount!.balance - amount})
          .eq('id', _selectedAccount!.id);

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Pago registrado exitosamente.',
          type: SnackbarType.success,
        );
        widget.onPaymentSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Error: $e',
          type: SnackbarType.error,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Text(
              'Amortizar Deuda (Pagar)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              widget.account.supplierName,
              style: const TextStyle(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),

            // ── NUEVO: Chips para seleccionar orden a pagar ──
            const Text(
              'Aplicar pago a:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (_loadingOrders)
              const Center(child: CircularProgressIndicator())
            else if (_pendingOrders.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'No hay órdenes de compra pendientes. El pago se registrará como abono libre a la cuenta.',
                  style: TextStyle(color: AppColors.success, fontSize: 13),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _OrderChip(
                      label: 'Automático (Deuda más antigua)',
                      isSelected: _selectedOrderId == null,
                      isTotalChip: true,
                      onTap: () {
                        setState(() {
                          _selectedOrderId = null;
                          _validarEntrada(_amountCtrl.text);
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    ..._pendingOrders.map((o) {
                      final pending = _pendingOf(o);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _OrderChip(
                          label:
                              'Orden #${o['id'].toString().substring(0, 6)} (Deuda: S/ ${pending.toStringAsFixed(2)})',
                          isSelected: _selectedOrderId == o['id'],
                          isTotalChip: false,
                          onTap: () {
                            setState(() {
                              _selectedOrderId = o['id'] as String;
                              _validarEntrada(_amountCtrl.text);
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Cuenta de salida de dinero
            const Text(
              'Cuenta desde donde se paga',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            if (_loadingAccounts)
              const Center(child: CircularProgressIndicator())
            else
              DropdownButtonFormField<_FinancialAccountOption>(
                initialValue: _selectedAccount,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items:
                    _accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a,
                            child: Text(
                              '${a.name} (S/ ${a.balance.toStringAsFixed(2)})',
                              style: TextStyle(
                                color:
                                    a.balance > 0
                                        ? Colors.black
                                        : AppColors.danger,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                onChanged: (v) {
                  setState(() => _selectedAccount = v);
                  if (v!.type == 'CAJA') _checkActiveShift(v.id);
                  _validarEntrada(_amountCtrl.text);
                },
              ),
            const SizedBox(height: 16),

            // Monto a pagar
            Container(
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      _errorMessage != null
                          ? AppColors.danger
                          : AppColors.border,
                ),
              ),
              child: TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                onChanged: _validarEntrada,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                decoration: InputDecoration(
                  hintText: 'Monto a pagar (Ej. 100.00)',
                  errorText: _errorMessage,
                  prefixIcon: Icon(
                    Icons.attach_money_rounded,
                    color:
                        _errorMessage != null
                            ? AppColors.danger
                            : AppColors.textMuted,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed:
                  (_errorMessage == null &&
                          _amountCtrl.text.isNotEmpty &&
                          !_isSaving)
                      ? _savePayment
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isSaving
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                      : const Text(
                        'Registrar Pago',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── WIDGET: CHIP PARA ORDEN ──────────────────────────────────────────────────
class _OrderChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isTotalChip;
  final VoidCallback onTap;

  const _OrderChip({
    required this.label,
    required this.isSelected,
    required this.isTotalChip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color borderColor;
    Color textColor;

    if (isSelected) {
      bgColor =
          isTotalChip
              ? AppColors.success.withValues(alpha: 0.1)
              : Colors.blue.withValues(alpha: 0.1);
      borderColor = isTotalChip ? AppColors.success : Colors.blue;
      textColor = isTotalChip ? AppColors.successDark : Colors.blue.shade800;
    } else {
      bgColor = AppColors.bg;
      borderColor = AppColors.border;
      textColor = AppColors.textSecondary;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: isSelected ? 1.5 : 1),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: (isTotalChip ? AppColors.success : Colors.blue)
                          .withValues(alpha: 0.22),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_rounded, size: 11, color: textColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
