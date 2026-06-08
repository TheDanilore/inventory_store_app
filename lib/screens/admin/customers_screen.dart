import 'dart:async';
import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/admin/customer_detail_screen.dart';
import 'package:inventory_store_app/screens/admin/widgets/customer_form_sheet.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── MODELOS ──────────────────────────────────────────────────────────────────

class CustomerSummary {
  final String id;
  final String fullName;
  final String? phone;
  final String? documentNumber;
  final String? documentType;
  final String? avatarUrl;
  final bool isActive;
  final int walletBalance;
  final DateTime createdAt;

  // Datos agregados desde orders
  final double totalSpent;
  final int orderCount;
  final DateTime? lastOrderAt;

  // Crédito
  final double currentDebt;
  final double creditLimit;
  final bool hasActiveCredit;

  const CustomerSummary({
    required this.id,
    required this.fullName,
    this.phone,
    this.documentNumber,
    this.documentType,
    this.avatarUrl,
    required this.isActive,
    required this.walletBalance,
    required this.createdAt,
    this.totalSpent = 0,
    this.orderCount = 0,
    this.lastOrderAt,
    this.currentDebt = 0,
    this.creditLimit = 0,
    this.hasActiveCredit = false,
  });
}

// ─── PANTALLA PRINCIPAL ───────────────────────────────────────────────────────

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  late final TabController _tabCtrl;

  List<CustomerSummary> _all = [];
  List<CustomerSummary> _filtered = [];
  bool _isLoading = true;

  // Stats globales
  int _totalCustomers = 0;
  int _activeCustomers = 0;
  double _totalRevenue = 0;
  double _totalDebt = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      // 1. Traer todos los customers
      final profiles = await _supabase
          .from('profiles')
          .select(
            'id, full_name, phone, document_number, document_type, avatar_url, is_active, wallet_balance, created_at',
          )
          .eq('role', 'customer')
          .order('full_name');

      // 2. Traer órdenes agrupadas por cliente (todos los estados)
      final orders = await _supabase
          .from('orders')
          .select('customer_id, total_amount, created_at');

      // Agregar por cliente
      final Map<String, _OrderAgg> agg = {};
      for (final o in (orders as List)) {
        final cid = o['customer_id'] as String?;
        if (cid == null) continue;
        final amount = (o['total_amount'] as num).toDouble();
        final date = DateTime.parse(o['created_at'] as String);
        if (!agg.containsKey(cid)) {
          agg[cid] = _OrderAgg();
        }
        agg[cid]!.total += amount;
        agg[cid]!.count++;
        if (agg[cid]!.lastDate == null || date.isAfter(agg[cid]!.lastDate!)) {
          agg[cid]!.lastDate = date;
        }
      }

      // 3. Traer créditos activos de todos los clientes
      final credits = await _supabase
          .from('customer_credits')
          .select('profile_id, current_debt, credit_limit, is_active');

      final Map<String, _CreditInfo> creditMap = {};
      for (final cr in (credits as List)) {
        final pid = cr['profile_id'] as String;
        creditMap[pid] = _CreditInfo(
          currentDebt: (cr['current_debt'] as num).toDouble(),
          creditLimit: (cr['credit_limit'] as num).toDouble(),
          isActive: cr['is_active'] as bool,
        );
      }

      final customers =
          (profiles as List).map((p) {
            final a = agg[p['id'] as String];
            final cr = creditMap[p['id'] as String];
            return CustomerSummary(
              id: p['id'] as String,
              fullName: p['full_name'] as String,
              phone: p['phone'] as String?,
              documentNumber: p['document_number'] as String?,
              documentType: p['document_type'] as String?,
              avatarUrl: p['avatar_url'] as String?,
              isActive: p['is_active'] as bool,
              walletBalance: p['wallet_balance'] as int,
              createdAt: DateTime.parse(p['created_at'] as String),
              totalSpent: a?.total ?? 0,
              orderCount: a?.count ?? 0,
              lastOrderAt: a?.lastDate,
              currentDebt: cr?.currentDebt ?? 0,
              creditLimit: cr?.creditLimit ?? 0,
              hasActiveCredit: cr?.isActive ?? false,
            );
          }).toList();

      double revenue = 0;
      double debt = 0;
      int active = 0;
      for (final c in customers) {
        revenue += c.totalSpent;
        debt += c.currentDebt;
        if (c.isActive) active++;
      }

      if (mounted) {
        setState(() {
          _all = customers;
          _filtered = List.from(customers);
          _totalCustomers = customers.length;
          _activeCustomers = active;
          _totalRevenue = revenue;
          _totalDebt = debt;
        });
      }
    } catch (e) {
      debugPrint('Error cargando clientes: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearch(String q) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final term = q.trim().toLowerCase();
      setState(() {
        _filtered =
            _all.where((c) {
              return c.fullName.toLowerCase().contains(term) ||
                  (c.documentNumber?.contains(term) ?? false) ||
                  (c.phone?.contains(term) ?? false);
            }).toList();
      });
    });
  }

  List<CustomerSummary> get _topCustomers {
    final sorted = List<CustomerSummary>.from(_all)
      ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
    return sorted.take(5).where((c) => c.totalSpent > 0).toList();
  }

  List<CustomerSummary> get _currentList {
    final list = List<CustomerSummary>.from(_filtered);
    if (_tabCtrl.index == 1) {
      list.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
    }
    return list;
  }

  void _openDetail(CustomerSummary customer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(customer: customer),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Clientes',
      showBackButton: true,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                onRefresh: _load,
                child: CustomScrollView(
                  slivers: [
                    // ── Stats globales ──────────────────────────────────
                    SliverToBoxAdapter(
                      child: _GlobalStatsBar(
                        total: _totalCustomers,
                        active: _activeCustomers,
                        revenue: _totalRevenue,
                        totalDebt: _totalDebt,
                      ),
                    ),

                    // ── Top 5 clientes ──────────────────────────────────
                    if (_topCustomers.isNotEmpty)
                      SliverToBoxAdapter(
                        child: _TopCustomersSection(
                          top: _topCustomers,
                          onTap: _openDetail,
                        ),
                      ),

                    // ── Buscador + Tabs ─────────────────────────────────
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Buscador
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: TextField(
                                controller: _searchCtrl,
                                onChanged: _onSearch,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Buscar por nombre, DNI o teléfono...',
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: AppColors.textMuted,
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Tabs
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
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                indicatorSize: TabBarIndicatorSize.tab,
                                dividerColor: Colors.transparent,
                                padding: const EdgeInsets.all(4),
                                tabs: const [
                                  Tab(text: 'Todos'),
                                  Tab(text: 'Mayor compra'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),

                    // ── Lista ───────────────────────────────────────────
                    if (_currentList.isEmpty)
                      const SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'Sin resultados',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final c = _currentList[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _CustomerCard(
                                customer: c,
                                rank: _tabCtrl.index == 1 ? index + 1 : null,
                                onTap: () => _openDetail(c),
                              ),
                            );
                          }, childCount: _currentList.length),
                        ),
                      ),
                  ],
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => CustomerFormSheet.show(context, onSaved: _load),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Nuevo cliente'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _OrderAgg {
  double total = 0;
  int count = 0;
  DateTime? lastDate;
}

class _CreditInfo {
  final double currentDebt;
  final double creditLimit;
  final bool isActive;
  const _CreditInfo({
    required this.currentDebt,
    required this.creditLimit,
    required this.isActive,
  });
}

// ─── WIDGET: Barra de stats globales ─────────────────────────────────────────

class _GlobalStatsBar extends StatelessWidget {
  final int total;
  final int active;
  final double revenue;
  final double totalDebt;

  const _GlobalStatsBar({
    required this.total,
    required this.active,
    required this.revenue,
    required this.totalDebt,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _StatItem(
            value: '$total',
            label: 'Total',
            icon: Icons.people_rounded,
          ),
          _VerticalDivider(),
          _StatItem(
            value: '$active',
            label: 'Activos',
            icon: Icons.check_circle_rounded,
          ),
          _VerticalDivider(),
          _StatItem(
            value: 'S/ ${_compact(revenue)}',
            label: 'Ingresos',
            icon: Icons.attach_money_rounded,
          ),
          if (totalDebt > 0) ...[
            _VerticalDivider(),
            _StatItem(
              value: 'S/ ${_compact(totalDebt)}',
              label: 'En crédito',
              icon: Icons.credit_card_rounded,
              valueColor: Colors.amber.shade200,
            ),
          ],
        ],
      ),
    );
  }

  String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color? valueColor;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withValues(alpha: 0.25),
    );
  }
}

// ─── WIDGET: Sección Top 5 ────────────────────────────────────────────────────

class _TopCustomersSection extends StatelessWidget {
  final List<CustomerSummary> top;
  final void Function(CustomerSummary) onTap;

  const _TopCustomersSection({required this.top, required this.onTap});

  static const _medals = ['🥇', '🥈', '🥉', '4°', '5°'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
          child: Row(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 6),
              const Text(
                'Top compradores',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: top.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final c = top[i];
              return GestureDetector(
                onTap: () => onTap(c),
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            _medals[i],
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Spacer(),
                          _MiniAvatar(name: c.fullName),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        c.fullName.split(' ').first,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'S/ ${c.totalSpent.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${c.orderCount} pedidos',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _MiniAvatar extends StatelessWidget {
  final String name;
  const _MiniAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: AppColors.primaryLight,
      child: Text(
        name.substring(0, 1).toUpperCase(),
        style: const TextStyle(
          color: AppColors.primaryDark,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// ─── WIDGET: Tarjeta de cliente ───────────────────────────────────────────────

class _CustomerCard extends StatelessWidget {
  final CustomerSummary customer;
  final int? rank;
  final VoidCallback onTap;

  const _CustomerCard({required this.customer, this.rank, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = customer;
    final hasOrders = c.orderCount > 0;
    final hasDebt = c.hasActiveCredit && c.currentDebt > 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              // Resaltar borde si tiene deuda pendiente
              color:
                  hasDebt
                      ? AppColors.danger.withValues(alpha: 0.4)
                      : AppColors.border,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Rank badge o avatar
              if (rank != null)
                _RankBadge(rank: rank!)
              else
                _AvatarBubble(name: c.fullName, isActive: c.isActive),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre + estado
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            c.fullName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!c.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.dangerLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Inactivo',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.danger,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Doc / Teléfono
                    if (c.documentNumber != null || c.phone != null)
                      Text(
                        [
                          if (c.documentNumber != null)
                            '${c.documentType ?? 'Doc'}: ${c.documentNumber}',
                          if (c.phone != null) c.phone!,
                        ].join(' • '),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Métricas
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _MetricChip(
                          icon: Icons.shopping_bag_outlined,
                          label: '${c.orderCount} pedidos',
                          color: AppColors.primary,
                        ),
                        if (hasOrders)
                          _MetricChip(
                            icon: Icons.attach_money_rounded,
                            label: 'S/ ${c.totalSpent.toStringAsFixed(0)}',
                            color: AppColors.success,
                          ),
                        if (c.walletBalance > 0)
                          _MetricChip(
                            icon: Icons.stars_rounded,
                            label: '${c.walletBalance} pts',
                            color: Colors.amber.shade700,
                          ),
                        // Indicador de deuda pendiente
                        if (hasDebt)
                          _MetricChip(
                            icon: Icons.credit_card_rounded,
                            label:
                                'Debe S/ ${c.currentDebt.toStringAsFixed(0)}',
                            color: AppColors.danger,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  final String name;
  final bool isActive;
  const _AvatarBubble({required this.name, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor:
              isActive ? AppColors.primaryLight : Colors.grey.shade200,
          child: Text(
            name.substring(0, 1).toUpperCase(),
            style: TextStyle(
              color: isActive ? AppColors.primaryDark : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isActive ? AppColors.success : Colors.grey.shade400,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  static const _colors = [
    Color(0xFFFFD700),
    Color(0xFFC0C0C0),
    Color(0xFFCD7F32),
  ];

  @override
  Widget build(BuildContext context) {
    final color =
        rank <= 3
            ? _colors[rank - 1]
            : AppColors.primary.withValues(alpha: 0.15);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: rank <= 3 ? 0.15 : 0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: rank <= 3 ? 2 : 1),
      ),
      child: Center(
        child: Text(
          rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '#$rank',
          style: TextStyle(
            fontSize: rank <= 3 ? 20 : 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetricChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
