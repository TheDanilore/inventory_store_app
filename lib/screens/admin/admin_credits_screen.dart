import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/screens/admin/admin_credit_movements_screen.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:inventory_store_app/shared/widgets/app_snackbar.dart';

// ─── MODELO LOCAL ─────────────────────────────────────────────────────────────

class CreditAccountModel {
  final String creditId;
  final String profileId;
  final String partnerName;
  final String? partnerDocument;
  final String? partnerDocumentType;
  final String? partnerPhone;
  final double creditLimit;
  final double currentDebt;
  final bool isActive;

  double get availableCredit =>
      (creditLimit - currentDebt).clamp(0.0, double.infinity);
  double get usagePercent =>
      creditLimit > 0 ? (currentDebt / creditLimit).clamp(0.0, 1.0) : 0.0;
  bool get isMaxedOut => currentDebt >= creditLimit && creditLimit > 0;

  CreditAccountModel({
    required this.creditId,
    required this.profileId,
    required this.partnerName,
    this.partnerDocument,
    this.partnerDocumentType,
    this.partnerPhone,
    required this.creditLimit,
    required this.currentDebt,
    required this.isActive,
  });

  /// Construye desde el join customer_credits + profiles
  factory CreditAccountModel.fromJoin(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>? ?? {};
    return CreditAccountModel(
      creditId: json['id'] as String,
      profileId: json['profile_id'] as String,
      partnerName: profile['full_name'] as String? ?? 'Cliente desconocido',
      partnerDocument: profile['document_number'] as String?,
      partnerDocumentType: profile['document_type'] as String?,
      partnerPhone: profile['phone'] as String?,
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0.0,
      currentDebt: (json['current_debt'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? false,
    );
  }

  factory CreditAccountModel.fromView(Map<String, dynamic> json) {
    return CreditAccountModel(
      creditId: json['credit_id'],
      profileId: json['profile_id'],
      partnerName: json['partner_name'] ?? 'Cliente desconocido',
      partnerDocument: json['partner_document'],
      partnerDocumentType: json['partner_document_type'],
      partnerPhone: json['partner_phone'],
      creditLimit: (json['credit_limit'] as num?)?.toDouble() ?? 0,
      currentDebt: (json['current_debt'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] ?? false,
    );
  }
}

// ─── PANTALLA PRINCIPAL ───────────────────────────────────────────────────────

class AdminCreditsScreen extends StatefulWidget {
  const AdminCreditsScreen({super.key});

  @override
  State<AdminCreditsScreen> createState() => _AdminCreditsScreenState();
}

class _AdminCreditsScreenState extends State<AdminCreditsScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  late final TabController _tabCtrl;

  List<CreditAccountModel> _all = [];
  List<CreditAccountModel> _filtered = [];
  bool _isLoading = true;

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

  // Query directa: customer_credits ← profiles (sin vista SQL)
  Future<void> _fetchAccounts() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('partner_credit_summary')
          .select()
          .order('current_debt', ascending: false);

      final accounts =
          (response as List)
              .map((item) => CreditAccountModel.fromView(item))
              .toList();

      for (final item in response) {
        debugPrint(
          'limit=${item['credit_limit']} debt=${item['current_debt']}',
        );
      }

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
    List<CreditAccountModel> list;
    if (term.isEmpty) {
      list = List.from(_all);
    } else {
      list =
          _all.where((a) {
            return a.partnerName.toLowerCase().contains(term) ||
                (a.partnerDocument?.contains(term) ?? false) ||
                (a.partnerPhone?.contains(term) ?? false);
          }).toList();
    }
    // Tab 0 = todos, Tab 1 = solo con deuda
    if (_tabCtrl.index == 1) {
      list = list.where((a) => a.currentDebt > 0 && a.isActive).toList();
    }
    _filtered = list;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _applyFilter(query));
    });
  }

  // ── Acciones sobre cuenta ──────────────────────────────────────────────────

  void _openAccountOptions(CreditAccountModel account) {
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
                  // Cabecera
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.tealLight,
                          child: Text(
                            account.partnerName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.tealDark,
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
                                account.partnerName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Deuda: S/ ${account.currentDebt.toStringAsFixed(2)} · '
                                'Límite: S/ ${account.creditLimit.toStringAsFixed(2)}',
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
                      color: AppColors.teal,
                    ),
                    title: const Text('Ver historial de movimientos'),
                    onTap: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => AdminCreditMovementsScreen(
                                creditId: account.creditId,
                                customerName: account.partnerName,
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
                      title: const Text('Registrar abono / pago'),
                      onTap: () {
                        Navigator.pop(ctx);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder:
                              (_) => _RegisterPaymentModal(
                                account: account,
                                onPaymentSaved: _fetchAccounts,
                              ),
                        );
                      },
                    ),

                  ListTile(
                    leading: const Icon(Icons.edit_rounded, color: Colors.blue),
                    title: const Text('Editar límite de crédito'),
                    onTap: () {
                      Navigator.pop(ctx);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder:
                            (_) => _CreditAccountModal(
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
                          ? 'Suspender línea de crédito'
                          : 'Reactivar línea de crédito',
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

  Future<void> _toggleAccountStatus(CreditAccountModel account) async {
    try {
      await _supabase
          .from('customer_credits')
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
              account.isActive
                  ? 'Línea de crédito suspendida.'
                  : 'Línea de crédito reactivada.',
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

  // ── BUILD ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Cuentas de Crédito',
      showBackButton: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed:
            () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _CreditAccountModal(onSaved: _fetchAccounts),
            ),
        backgroundColor: AppColors.teal,
        icon: const Icon(Icons.add_card_rounded, color: Colors.white),
        label: const Text(
          'Nueva cuenta',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // ── Stats globales ──────────────────────────────────────────────
          if (!_isLoading)
            _GlobalStatsBar(
              totalDebt: _totalDebt,
              activeAccounts: _activeAccounts,
              suspendedAccounts: _suspendedAccounts,
              maxedOutAccounts: _maxedOutAccounts,
            ),

          // ── Buscador + Tabs ─────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, DNI o teléfono...',
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
                      color: AppColors.teal,
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
                            const Text('Con deuda'),
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

          // ── Lista ───────────────────────────────────────────────────────
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
                            Icons.credit_score_rounded,
                            size: 60,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _tabCtrl.index == 1
                                ? 'Sin cuentas con deuda pendiente'
                                : 'No hay cuentas de crédito',
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
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final account = _filtered[index];
                          return _CreditCard(
                            account: account,
                            onTap: () => _openAccountOptions(account),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

// ─── WIDGET: Barra de stats globales ─────────────────────────────────────────

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

  String _compact(double v) {
    if (v >= 1000) return 'S/ ${(v / 1000).toStringAsFixed(1)}K';
    return 'S/ ${v.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.teal, AppColors.tealDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatItem(
            icon: Icons.credit_card_rounded,
            value: '$activeAccounts',
            label: 'Activas',
          ),
          _Divider(),
          _StatItem(
            icon: Icons.warning_amber_rounded,
            value: '$maxedOutAccounts',
            label: 'Al límite',
            valueColor:
                maxedOutAccounts > 0 ? Colors.orange.shade200 : Colors.white,
          ),
          _Divider(),
          _StatItem(
            icon: Icons.block_rounded,
            value: '$suspendedAccounts',
            label: 'Suspendidas',
            valueColor:
                suspendedAccounts > 0 ? Colors.red.shade200 : Colors.white,
          ),
          _Divider(),
          _StatItem(
            icon: Icons.account_balance_rounded,
            value: _compact(totalDebt),
            label: 'Deuda total',
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

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 1,
      color: Colors.white.withValues(alpha: 0.25),
    );
  }
}

// ─── WIDGET: Tarjeta de cuenta de crédito ────────────────────────────────────

class _CreditCard extends StatelessWidget {
  final CreditAccountModel account;
  final VoidCallback onTap;

  const _CreditCard({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final pct = account.usagePercent;
    final isRisk = pct >= 0.8;
    final barColor =
        account.isMaxedOut
            ? AppColors.danger
            : isRisk
            ? Colors.orange
            : AppColors.teal;

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
              // ── Cabecera ──
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                        account.isActive
                            ? AppColors.tealLight
                            : Colors.grey.shade200,
                    child: Text(
                      account.partnerName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color:
                            account.isActive ? AppColors.tealDark : Colors.grey,
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
                          account.partnerName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (account.partnerDocument != null ||
                            account.partnerPhone != null)
                          Text(
                            [
                              if (account.partnerDocument != null)
                                '${account.partnerDocumentType ?? 'Doc'}: ${account.partnerDocument}',
                              if (account.partnerPhone != null)
                                account.partnerPhone!,
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Badge de estado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          account.isActive
                              ? AppColors.successLight
                              : AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      account.isActive ? 'ACTIVO' : 'SUSPENDIDO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color:
                            account.isActive
                                ? AppColors.success
                                : AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // ── Montos ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Deuda actual',
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
                                  ? (isRisk
                                      ? AppColors.danger
                                      : AppColors.textPrimary)
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
                                  ? AppColors.teal
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

              // ── Barra de progreso ──
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 8,
                  backgroundColor: AppColors.bg,
                  color: barColor,
                ),
              ),
              const SizedBox(height: 6),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    account.isMaxedOut
                        ? '⚠ Límite alcanzado'
                        : '${(pct * 100).toStringAsFixed(0)}% utilizado',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color:
                          account.isMaxedOut
                              ? AppColors.danger
                              : AppColors.textMuted,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textMuted,
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

// ─── MODAL: Crear / editar cuenta de crédito ─────────────────────────────────

class _CreditAccountModal extends StatefulWidget {
  final VoidCallback onSaved;
  final CreditAccountModel? accountToEdit;

  const _CreditAccountModal({required this.onSaved, this.accountToEdit});

  @override
  State<_CreditAccountModal> createState() => _CreditAccountModalState();
}

class _CreditAccountModalState extends State<_CreditAccountModal> {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  final _limitCtrl = TextEditingController();
  Timer? _debounce;

  bool _isSearching = false;
  bool _isSaving = false;
  List<Map<String, dynamic>> _matches = [];

  String? _selectedProfileId;
  String? _selectedProfileName;

  bool get _isEditing => widget.accountToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _selectedProfileId = widget.accountToEdit!.profileId;
      _selectedProfileName = widget.accountToEdit!.partnerName;
      _searchCtrl.text = _selectedProfileName!;
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
    if (_selectedProfileId != null) {
      setState(() {
        _selectedProfileId = null;
        _selectedProfileName = null;
      });
    }
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _searchClients(query),
    );
  }

  Future<void> _searchClients(String query) async {
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
      final response = await _supabase
          .from('profiles')
          .select('id, full_name, document_number, document_type, phone')
          .eq('role', 'customer') // ← solo clientes
          .eq('is_active', true)
          .or(
            'full_name.ilike.%$text%,document_number.ilike.%$text%,phone.ilike.%$text%',
          )
          .limit(6);

      if (mounted) {
        setState(() {
          _matches = List<Map<String, dynamic>>.from(response);
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectClient(Map<String, dynamic> client) {
    setState(() {
      _selectedProfileId = client['id'] as String;
      _selectedProfileName = client['full_name'] as String;
      _searchCtrl.text = _selectedProfileName!;
      _matches = [];
      FocusScope.of(context).unfocus();
    });
  }

  Future<void> _saveAccount() async {
    if (_selectedProfileId == null) {
      AppSnackbar.show(
        context,
        message: 'Selecciona un cliente primero.',
        type: SnackbarType.error,
      );
      return;
    }

    final limitVal = double.tryParse(_limitCtrl.text.trim()) ?? 0.0;
    if (limitVal <= 0) {
      AppSnackbar.show(
        context,
        message: 'Ingresa un límite de crédito válido (mayor a 0).',
        type: SnackbarType.error,
      );
      return;
    }

    // El límite no puede ser menor a la deuda actual al editar
    if (_isEditing &&
        limitVal < widget.accountToEdit!.currentDebt &&
        widget.accountToEdit!.currentDebt > 0) {
      AppSnackbar.show(
        context,
        message:
            'El límite no puede ser menor a la deuda actual '
            '(S/ ${widget.accountToEdit!.currentDebt.toStringAsFixed(2)}).',
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
            .from('customer_credits')
            .update({
              'credit_limit': limitVal,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', widget.accountToEdit!.creditId);
      } else {
        // Crear nueva: current_debt = 0 siempre
        await _supabase.from('customer_credits').insert({
          'profile_id': _selectedProfileId,
          'credit_limit': limitVal,
          'current_debt': 0.0,
          'is_active': true,
          'created_by': adminProfileId,
        });
      }

      if (mounted) {
        AppSnackbar.show(
          context,
          message:
              _isEditing
                  ? 'Límite de crédito actualizado.'
                  : 'Línea de crédito aprobada.',
          type: SnackbarType.success,
        );
        widget.onSaved();
        Navigator.pop(context);
      }
    } on PostgrestException catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message:
              e.code == '23505'
                  ? 'Este cliente ya tiene una cuenta de crédito.'
                  : 'Error: ${e.message}',
          type: SnackbarType.error,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
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
                ? 'Editar límite de crédito'
                : 'Aprobar línea de crédito',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          // ── Buscador de cliente ──
          const Text(
            'Cliente',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: _isEditing ? Colors.grey.shade100 : AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _selectedProfileId != null
                        ? AppColors.teal
                        : AppColors.border,
              ),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              enabled: !_isEditing,
              style: TextStyle(
                color:
                    _isEditing ? Colors.grey.shade600 : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, DNI o teléfono...',
                prefixIcon: Icon(
                  _selectedProfileId != null
                      ? Icons.check_circle_rounded
                      : Icons.search_rounded,
                  color:
                      _selectedProfileId != null
                          ? AppColors.teal
                          : AppColors.textMuted,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // Resultados de búsqueda
          if (_isSearching)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_matches.isNotEmpty && _selectedProfileId == null)
            Container(
              margin: const EdgeInsets.only(top: 4),
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(12),
                color: Colors.white,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _matches.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final client = _matches[index];
                  final docType = client['document_type'] as String? ?? 'Doc';
                  final docNum = client['document_number'] as String?;
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.tealLight,
                      child: Text(
                        (client['full_name'] as String)
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.tealDark,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      client['full_name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: docNum != null ? Text('$docType: $docNum') : null,
                    onTap: () => _selectClient(client),
                  );
                },
              ),
            ),

          const SizedBox(height: 16),

          // ── Límite de crédito ──
          const Text(
            'Límite de crédito (S/)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
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
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Ej. 500.00',
                prefixIcon: Icon(
                  Icons.attach_money_rounded,
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          // Nota: deuda actual al editar
          if (_isEditing && widget.accountToEdit!.currentDebt > 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 13,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  'Deuda actual: S/ ${widget.accountToEdit!.currentDebt.toStringAsFixed(2)}. '
                  'El límite no puede ser menor.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isSaving ? null : _saveAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
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
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : Text(
                      _isEditing
                          ? 'Actualizar límite'
                          : 'Crear cuenta de crédito',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

// ─── MODAL: Registrar abono / pago ────────────────────────────────────────────

class _RegisterPaymentModal extends StatefulWidget {
  final CreditAccountModel account;
  final VoidCallback onPaymentSaved;

  const _RegisterPaymentModal({
    required this.account,
    required this.onPaymentSaved,
  });

  @override
  State<_RegisterPaymentModal> createState() => _RegisterPaymentModalState();
}

class _RegisterPaymentModalState extends State<_RegisterPaymentModal> {
  final _supabase = Supabase.instance.client;
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _paymentMethod = 'EFECTIVO';
  bool _isSaving = false;

  static const _paymentMethods = [
    'EFECTIVO',
    'YAPE',
    'PLIN',
    'TRANSFERENCIA',
    'OTRO',
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _savePayment() async {
    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amount <= 0) {
      AppSnackbar.show(
        context,
        message: 'Ingresa un monto válido mayor a 0.',
        type: SnackbarType.error,
      );
      return;
    }
    if (amount > widget.account.currentDebt) {
      AppSnackbar.show(
        context,
        message:
            'El abono (S/ ${amount.toStringAsFixed(2)}) supera la '
            'deuda actual (S/ ${widget.account.currentDebt.toStringAsFixed(2)}).',
        type: SnackbarType.error,
      );
      return;
    }

    setState(() => _isSaving = true);
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

      // 1. Insertar movimiento PAYMENT en credit_movements
      await _supabase.from('credit_movements').insert({
        'credit_id': widget.account.creditId,
        'movement_type': 'PAYMENT',
        'amount': amount,
        'payment_method': _paymentMethod,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        'created_by': adminProfileId,
      });

      // 2. Actualizar current_debt en customer_credits
      final newDebt = (widget.account.currentDebt - amount).clamp(
        0.0,
        double.infinity,
      );
      await _supabase
          .from('customer_credits')
          .update({
            'current_debt': newDebt,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.account.creditId);

      if (mounted) {
        AppSnackbar.show(
          context,
          message: 'Pago de S/ ${amount.toStringAsFixed(2)} registrado.',
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
    final debt = widget.account.currentDebt;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
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

          // Encabezado
          Row(
            children: [
              const Icon(Icons.payments_rounded, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Registrar abono / pago',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      widget.account.partnerName,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Deuda actual
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.dangerLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.money_off_rounded,
                  color: AppColors.danger,
                  size: 20,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Deuda actual',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'S/ ${debt.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Botones de monto rápido
          if (debt > 0) ...[
            const Text(
              'Monto rápido',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (debt >= 50)
                  _QuickAmountChip(
                    label: 'S/ 50',
                    onTap: () => _amountCtrl.text = '50.00',
                  ),
                if (debt >= 100)
                  _QuickAmountChip(
                    label: 'S/ 100',
                    onTap: () => _amountCtrl.text = '100.00',
                  ),
                if (debt >= 200)
                  _QuickAmountChip(
                    label: 'S/ 200',
                    onTap: () => _amountCtrl.text = '200.00',
                  ),
                _QuickAmountChip(
                  label: 'Total (S/ ${debt.toStringAsFixed(2)})',
                  onTap: () => _amountCtrl.text = debt.toStringAsFixed(2),
                  isHighlight: true,
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],

          // Monto del abono
          const Text(
            'Monto del abono (S/)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                hintText: 'Ej. 50.00',
                prefixIcon: Icon(
                  Icons.attach_money_rounded,
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Método de pago
          const Text(
            'Método de pago',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                _paymentMethods.map((method) {
                  final selected = _paymentMethod == method;
                  return GestureDetector(
                    onTap: () => setState(() => _paymentMethod = method),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.teal : AppColors.bg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? AppColors.teal : AppColors.border,
                        ),
                      ),
                      child: Text(
                        method,
                        style: TextStyle(
                          color:
                              selected ? Colors.white : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 14),

          // Notas
          const Text(
            'Notas (opcional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Ej. Pago del pedido #123...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: _isSaving ? null : _savePayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
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
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                    : const Text(
                      'Guardar pago',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

class _QuickAmountChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isHighlight;

  const _QuickAmountChip({
    required this.label,
    required this.onTap,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color:
              isHighlight
                  ? AppColors.success.withValues(alpha: 0.12)
                  : AppColors.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHighlight ? AppColors.success : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isHighlight ? AppColors.success : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
