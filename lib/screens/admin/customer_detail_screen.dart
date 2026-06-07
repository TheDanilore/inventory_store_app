import 'package:flutter/material.dart';
import 'package:inventory_store_app/screens/admin/customers_screen.dart';
import 'package:inventory_store_app/screens/admin/widgets/customer_form_sheet.dart';
import 'package:inventory_store_app/shared/theme/app_colors.dart';
import 'package:inventory_store_app/shared/widgets/admin_layout.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

// ─── MODELOS LOCALES ──────────────────────────────────────────────────────────

class _TopProduct {
  final String productName;
  final int totalQuantity;
  final double totalSpent;

  const _TopProduct({
    required this.productName,
    required this.totalQuantity,
    required this.totalSpent,
  });
}

class _RecentOrder {
  final String id;
  final DateTime createdAt;
  final double totalAmount;
  final String status;
  final String paymentStatus;
  final String paymentMethod;

  const _RecentOrder({
    required this.id,
    required this.createdAt,
    required this.totalAmount,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
  });
}

// ─── PANTALLA PRINCIPAL ───────────────────────────────────────────────────────

class CustomerDetailScreen extends StatefulWidget {
  final CustomerSummary customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  List<_TopProduct> _topProducts = [];
  List<_RecentOrder> _recentOrders = [];
  double _avgOrderValue = 0;
  double _currentDebt = 0;
  double _creditLimit = 0;
  bool _hasCredit = false;

  @override
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es', null).then((_) => _load()); // ← CAMBIO
  }

  Future<void> _load() async {
    try {
      await Future.wait([_loadOrders(), _loadTopProducts(), _loadCredit()]);
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOrders() async {
    final response = await _supabase
        .from('orders')
        .select(
          'id, created_at, total_amount, status, payment_status, payment_method',
        )
        .eq('customer_id', widget.customer.id)
        .order('created_at', ascending: false)
        .limit(20);

    final orders =
        (response as List)
            .map(
              (o) => _RecentOrder(
                id: o['id'] as String,
                createdAt: DateTime.parse(o['created_at'] as String),
                totalAmount: (o['total_amount'] as num).toDouble(),
                status: o['status'] as String,
                paymentStatus: o['payment_status'] as String,
                paymentMethod: o['payment_method'] as String,
              ),
            )
            .toList();

    double sum = 0;
    for (final o in orders) {
      sum += o.totalAmount;
    }

    if (mounted) {
      setState(() {
        _recentOrders = orders;
        _avgOrderValue = orders.isEmpty ? 0 : sum / orders.length;
      });
    }
  }

  Future<void> _loadTopProducts() async {
    // Traer order_items de todos los pedidos del cliente
    final ordersResp = await _supabase
        .from('orders')
        .select('id')
        .eq('customer_id', widget.customer.id);

    final orderIds =
        (ordersResp as List).map((o) => o['id'] as String).toList();

    if (orderIds.isEmpty) return;

    final itemsResp = await _supabase
        .from('order_items')
        .select('quantity, applied_price, products(name)')
        .filter('order_id', 'in', '(${orderIds.map((e) => '"$e"').join(',')})');

    // Agrupar por producto
    final Map<String, _MutableProduct> agg = {};
    for (final item in (itemsResp as List)) {
      final pName =
          (item['products'] as Map?)?['name'] as String? ?? 'Producto';
      final qty = (item['quantity'] as num).toInt();
      final price = (item['applied_price'] as num).toDouble();

      if (!agg.containsKey(pName)) {
        agg[pName] = _MutableProduct();
      }
      agg[pName]!.qty += qty;
      agg[pName]!.total += qty * price;
    }

    final sorted =
        agg.entries.toList()
          ..sort((a, b) => b.value.qty.compareTo(a.value.qty));

    if (mounted) {
      setState(() {
        _topProducts =
            sorted
                .take(5)
                .map(
                  (e) => _TopProduct(
                    productName: e.key,
                    totalQuantity: e.value.qty,
                    totalSpent: e.value.total,
                  ),
                )
                .toList();
      });
    }
  }

  Future<void> _loadCredit() async {
    final resp =
        await _supabase
            .from('customer_credits')
            .select('current_debt, credit_limit, is_active')
            .eq('profile_id', widget.customer.id)
            .maybeSingle();

    if (resp != null && mounted) {
      setState(() {
        _hasCredit = true;
        _currentDebt = (resp['current_debt'] as num).toDouble();
        _creditLimit = (resp['credit_limit'] as num).toDouble();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;

    return AdminLayout(
      title: c.fullName.split(' ').first,
      showBackButton: true,
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : CustomScrollView(
                slivers: [
                  // ── Header del cliente ──────────────────────────────
                  SliverToBoxAdapter(child: _CustomerHeader(customer: c)),

                  // ── KPIs ────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _KpiRow(
                      totalSpent: c.totalSpent,
                      orderCount: c.orderCount,
                      avgOrder: _avgOrderValue,
                      walletBalance: c.walletBalance,
                    ),
                  ),

                  // ── Crédito (si tiene) ───────────────────────────────
                  if (_hasCredit)
                    SliverToBoxAdapter(
                      child: _CreditSection(
                        debt: _currentDebt,
                        limit: _creditLimit,
                      ),
                    ),

                  // ── Productos favoritos ──────────────────────────────
                  if (_topProducts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _TopProductsSection(
                        products: _topProducts,
                        maxQty: _topProducts.first.totalQuantity,
                      ),
                    ),

                  // ── Pedidos recientes ────────────────────────────────
                  SliverToBoxAdapter(
                    child: _RecentOrdersSection(orders: _recentOrders),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
    );
  }
}

class _MutableProduct {
  int qty = 0;
  double total = 0;
}

// ─── WIDGET: Header ───────────────────────────────────────────────────────────

class _CustomerHeader extends StatelessWidget {
  final CustomerSummary customer;
  const _CustomerHeader({required this.customer});

  @override
  Widget build(BuildContext context) {
    final c = customer;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors:
              c.isActive
                  ? [AppColors.primary, AppColors.primaryDark]
                  : [Colors.grey.shade600, Colors.grey.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (c.isActive ? AppColors.primary : Colors.grey).withValues(
              alpha: 0.3,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar grande
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Text(
              c.fullName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                if (c.documentNumber != null)
                  Text(
                    '${c.documentType ?? 'Doc'}: ${c.documentNumber}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                if (c.phone != null)
                  Text(
                    '📞 ${c.phone}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _HeaderChip(
                      label: c.isActive ? 'Activo' : 'Inactivo',
                      color: c.isActive ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 6),
                    _HeaderChip(
                      label:
                          'Desde ${DateFormat('MMM yyyy', 'es').format(c.createdAt)}',
                      color: Colors.white54,
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 👇 AGREGA EL BOTÓN AQUÍ
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            onPressed:
                () => CustomerFormSheet.show(
                  context,
                  customer: c, // Usas la variable local 'c' que ya definiste
                  onSaved: () {
                    /* recargar detalle */
                  },
                ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final String label;
  final Color color;
  const _HeaderChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

// ─── WIDGET: KPIs ─────────────────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final double totalSpent;
  final int orderCount;
  final double avgOrder;
  final int walletBalance;

  const _KpiRow({
    required this.totalSpent,
    required this.orderCount,
    required this.avgOrder,
    required this.walletBalance,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _KpiCard(
            icon: Icons.attach_money_rounded,
            value: 'S/ ${totalSpent.toStringAsFixed(0)}',
            label: 'Total gastado',
            color: AppColors.success,
          ),
          const SizedBox(width: 10),
          _KpiCard(
            icon: Icons.shopping_bag_rounded,
            value: '$orderCount',
            label: 'Pedidos',
            color: AppColors.primary,
          ),
          const SizedBox(width: 10),
          _KpiCard(
            icon: Icons.bar_chart_rounded,
            value: 'S/ ${avgOrder.toStringAsFixed(0)}',
            label: 'Promedio',
            color: Colors.purple,
          ),
          const SizedBox(width: 10),
          _KpiCard(
            icon: Icons.stars_rounded,
            value: '$walletBalance',
            label: 'Monedas',
            color: Colors.amber.shade700,
          ),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _KpiCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── WIDGET: Crédito ──────────────────────────────────────────────────────────

class _CreditSection extends StatelessWidget {
  final double debt;
  final double limit;

  const _CreditSection({required this.debt, required this.limit});

  @override
  Widget build(BuildContext context) {
    final pct = limit > 0 ? (debt / limit).clamp(0.0, 1.0) : 0.0;
    final available = (limit - debt).clamp(0.0, double.infinity);
    final isRisk = pct >= 0.8;

    return _SectionCard(
      title: 'Línea de Crédito',
      icon: Icons.credit_card_rounded,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _CreditStat(
                  label: 'Deuda',
                  value: 'S/ ${debt.toStringAsFixed(2)}',
                  color: AppColors.danger,
                ),
              ),
              Expanded(
                child: _CreditStat(
                  label: 'Disponible',
                  value: 'S/ ${available.toStringAsFixed(2)}',
                  color: AppColors.success,
                ),
              ),
              Expanded(
                child: _CreditStat(
                  label: 'Límite',
                  value: 'S/ ${limit.toStringAsFixed(2)}',
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isRisk ? AppColors.danger : AppColors.success,
              ),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(pct * 100).toStringAsFixed(0)}% usado',
              style: TextStyle(
                fontSize: 11,
                color: isRisk ? AppColors.danger : AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _CreditStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

// ─── WIDGET: Top productos ────────────────────────────────────────────────────

class _TopProductsSection extends StatelessWidget {
  final List<_TopProduct> products;
  final int maxQty;

  const _TopProductsSection({required this.products, required this.maxQty});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Productos más comprados',
      icon: Icons.favorite_rounded,
      child: Column(
        children:
            products.asMap().entries.map((entry) {
              final i = entry.key;
              final p = entry.value;
              final pct = maxQty > 0 ? p.totalQuantity / maxQty : 0.0;
              final colors = [
                AppColors.primary,
                AppColors.success,
                Colors.purple,
                Colors.orange,
                Colors.teal,
              ];
              final color = colors[i % colors.length];

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${p.totalQuantity} uds',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'S/ ${p.totalSpent.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: color.withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }
}

// ─── WIDGET: Pedidos recientes ────────────────────────────────────────────────

class _RecentOrdersSection extends StatelessWidget {
  final List<_RecentOrder> orders;

  const _RecentOrdersSection({required this.orders});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Pedidos recientes',
      icon: Icons.receipt_long_rounded,
      child:
          orders.isEmpty
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Sin pedidos aún',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              )
              : Column(
                children: orders.map((o) => _OrderRow(order: o)).toList(),
              ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final _RecentOrder order;
  const _OrderRow({required this.order});

  Color get _statusColor {
    switch (order.paymentStatus) {
      case 'PAID':
        return AppColors.success;
      case 'PENDING':
        return Colors.orange;
      case 'PARTIAL':
        return Colors.blue;
      default:
        return AppColors.textMuted;
    }
  }

  String get _statusLabel {
    switch (order.paymentStatus) {
      case 'PAID':
        return 'Pagado';
      case 'PENDING':
        return 'Pendiente';
      case 'PARTIAL':
        return 'Parcial';
      default:
        return order.paymentStatus;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.bg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('d MMM yyyy', 'es').format(order.createdAt),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                Text(
                  order.paymentMethod,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'S/ ${order.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: _statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── WIDGET REUTILIZABLE: Tarjeta de sección ──────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(16), child: child),
        ],
      ),
    );
  }
}
