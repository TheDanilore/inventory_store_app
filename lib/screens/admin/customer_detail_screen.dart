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
  final double amountPaid;
  final double discountAmount;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final int pointsEarned;
  final int pointsUsed;
  final DateTime? dueDate;

  const _RecentOrder({
    required this.id,
    required this.createdAt,
    required this.totalAmount,
    required this.amountPaid,
    required this.discountAmount,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.pointsEarned,
    required this.pointsUsed,
    this.dueDate,
  });

  double get pendingAmount => totalAmount - amountPaid;
}

class _UserAddress {
  final String addressLine;
  final String district;
  final String province;
  final String department;
  final String? reference;
  final bool isDefault;

  const _UserAddress({
    required this.addressLine,
    required this.district,
    required this.province,
    required this.department,
    this.reference,
    required this.isDefault,
  });
}

class _CreditMovement {
  final String movementType; // 'CHARGE' | 'PAYMENT'
  final double amount;
  final String? paymentMethod;
  final String? notes;
  final DateTime createdAt;

  const _CreditMovement({
    required this.movementType,
    required this.amount,
    this.paymentMethod,
    this.notes,
    required this.createdAt,
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
  List<_UserAddress> _addresses = [];
  List<_CreditMovement> _creditMovements = [];
  double _avgOrderValue = 0;
  double _currentDebt = 0;
  double _creditLimit = 0;
  bool _hasCredit = false;
  bool _creditIsActive = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es', null).then((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadOrders(),
        _loadTopProducts(),
        _loadCredit(),
        _loadAddresses(),
      ]);
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
          'id, created_at, total_amount, amount_paid, discount_amount, '
          'status, payment_status, payment_method, points_earned, points_used, due_date',
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
                amountPaid: (o['amount_paid'] as num).toDouble(),
                discountAmount: (o['discount_amount'] as num).toDouble(),
                status: o['status'] as String,
                paymentStatus: o['payment_status'] as String,
                paymentMethod: o['payment_method'] as String,
                pointsEarned: (o['points_earned'] as num).toInt(),
                pointsUsed: (o['points_used'] as num).toInt(),
                dueDate:
                    o['due_date'] != null
                        ? DateTime.tryParse(o['due_date'] as String)
                        : null,
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

    final Map<String, _MutableProduct> agg = {};
    for (final item in (itemsResp as List)) {
      final pName =
          (item['products'] as Map?)?['name'] as String? ?? 'Producto';
      final qty = (item['quantity'] as num).toInt();
      final price = (item['applied_price'] as num).toDouble();

      agg.putIfAbsent(pName, () => _MutableProduct());
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
            .select('id, current_debt, credit_limit, is_active')
            .eq('profile_id', widget.customer.id)
            .maybeSingle();

    if (resp != null && mounted) {
      final creditId = resp['id'] as String;
      final isActive = resp['is_active'] as bool;
      setState(() {
        _hasCredit = true;
        _creditIsActive = isActive;
        _currentDebt = (resp['current_debt'] as num).toDouble();
        _creditLimit = (resp['credit_limit'] as num).toDouble();
      });

      // Cargar movimientos de crédito recientes
      await _loadCreditMovements(creditId);
    }
  }

  Future<void> _loadCreditMovements(String creditId) async {
    final resp = await _supabase
        .from('credit_movements')
        .select('movement_type, amount, payment_method, notes, created_at')
        .eq('credit_id', creditId)
        .order('created_at', ascending: false)
        .limit(10);

    if (mounted) {
      setState(() {
        _creditMovements =
            (resp as List)
                .map(
                  (m) => _CreditMovement(
                    movementType: m['movement_type'] as String,
                    amount: (m['amount'] as num).toDouble(),
                    paymentMethod: m['payment_method'] as String?,
                    notes: m['notes'] as String?,
                    createdAt: DateTime.parse(m['created_at'] as String),
                  ),
                )
                .toList();
      });
    }
  }

  Future<void> _loadAddresses() async {
    final resp = await _supabase
        .from('user_addresses')
        .select(
          'address_line, district, province, department, reference, is_default',
        )
        .eq('profile_id', widget.customer.id)
        .order('is_default', ascending: false);

    if (mounted) {
      setState(() {
        _addresses =
            (resp as List)
                .map(
                  (a) => _UserAddress(
                    addressLine: a['address_line'] as String,
                    district: a['district'] as String,
                    province: a['province'] as String,
                    department: a['department'] as String,
                    reference: a['reference'] as String?,
                    isDefault: a['is_default'] as bool,
                  ),
                )
                .toList();
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
                  SliverToBoxAdapter(
                    child: _CustomerHeader(
                      customer: c,
                      onEdit:
                          () => CustomerFormSheet.show(
                            context,
                            customer: c,
                            onSaved: _load,
                          ),
                    ),
                  ),

                  // ── KPIs ────────────────────────────────────────────
                  SliverToBoxAdapter(
                    child: _KpiRow(
                      totalSpent: c.totalSpent,
                      orderCount: c.orderCount,
                      avgOrder: _avgOrderValue,
                      walletBalance: c.walletBalance,
                    ),
                  ),

                  // ── Crédito ──────────────────────────────────────────
                  if (_hasCredit)
                    SliverToBoxAdapter(
                      child: _CreditSection(
                        debt: _currentDebt,
                        limit: _creditLimit,
                        isActive: _creditIsActive,
                        movements: _creditMovements,
                      ),
                    ),

                  // ── Direcciones ──────────────────────────────────────
                  if (_addresses.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _AddressesSection(addresses: _addresses),
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
  final VoidCallback onEdit;
  const _CustomerHeader({required this.customer, required this.onEdit});

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
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            onPressed: onEdit,
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
            label: 'Total',
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
  final bool isActive;
  final List<_CreditMovement> movements;

  const _CreditSection({
    required this.debt,
    required this.limit,
    required this.isActive,
    required this.movements,
  });

  @override
  Widget build(BuildContext context) {
    final pct = limit > 0 ? (debt / limit).clamp(0.0, 1.0) : 0.0;
    final available = (limit - debt).clamp(0.0, double.infinity);
    final isRisk = pct >= 0.8;

    return _SectionCard(
      title: 'Línea de Crédito',
      icon: Icons.credit_card_rounded,
      trailing:
          !isActive
              ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Inactivo',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats principales
          Row(
            children: [
              Expanded(
                child: _CreditStat(
                  label: 'Deuda',
                  value: 'S/ ${debt.toStringAsFixed(2)}',
                  color: debt > 0 ? AppColors.danger : AppColors.textMuted,
                ),
              ),
              Expanded(
                child: _CreditStat(
                  label: 'Disponible',
                  value: 'S/ ${available.toStringAsFixed(2)}',
                  color: isActive ? AppColors.success : AppColors.textMuted,
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
          // Barra de progreso
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

          // Movimientos de crédito recientes
          if (movements.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Text(
              'Movimientos recientes',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ...movements.take(5).map((m) => _CreditMovementRow(movement: m)),
          ],
        ],
      ),
    );
  }
}

class _CreditMovementRow extends StatelessWidget {
  final _CreditMovement movement;
  const _CreditMovementRow({required this.movement});

  @override
  Widget build(BuildContext context) {
    final isCharge = movement.movementType == 'CHARGE';
    final color = isCharge ? AppColors.danger : AppColors.success;
    final icon =
        isCharge ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final prefix = isCharge ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCharge
                      ? 'Cargo'
                      : 'Pago${movement.paymentMethod != null ? ' (${movement.paymentMethod})' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (movement.notes != null && movement.notes!.isNotEmpty)
                  Text(
                    movement.notes!,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$prefix S/ ${movement.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                DateFormat('d MMM', 'es').format(movement.createdAt),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textMuted,
                ),
              ),
            ],
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

// ─── WIDGET: Direcciones ──────────────────────────────────────────────────────

class _AddressesSection extends StatelessWidget {
  final List<_UserAddress> addresses;
  const _AddressesSection({required this.addresses});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Direcciones',
      icon: Icons.location_on_rounded,
      child: Column(
        children: addresses.map((a) => _AddressRow(address: a)).toList(),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final _UserAddress address;
  const _AddressRow({required this.address});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:
                  address.isDefault
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : AppColors.bg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              address.isDefault
                  ? Icons.home_rounded
                  : Icons.location_on_outlined,
              size: 14,
              color:
                  address.isDefault ? AppColors.primary : AppColors.textMuted,
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
                        address.addressLine,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (address.isDefault)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Principal',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  '${address.district}, ${address.province} - ${address.department}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                if (address.reference != null && address.reference!.isNotEmpty)
                  Text(
                    'Ref: ${address.reference}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
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
                children:
                    orders.take(5).map((o) => _OrderRow(order: o)).toList(),
              ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final _RecentOrder order;
  const _OrderRow({required this.order});

  bool get _isCancelled => order.status.toUpperCase() == 'CANCELLED';

  Color get _statusColor {
    // Prioridad: Si está cancelado/devuelto, color rojo
    if (_isCancelled) return AppColors.danger;

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
    // Prioridad: Si está cancelado, etiqueta "Cancelado"
    if (_isCancelled) return 'Cancelado';

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

  String _methodLabel(String method) {
    switch (method.toUpperCase()) {
      case 'EFECTIVO':
        return 'Efectivo';
      case 'CREDITO':
      case 'CRÉDITO':
        return 'Crédito';
      case 'YAPE':
        return 'Yape';
      case 'TRANSFERENCIA':
        return 'Transferencia';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prioridad: Si está cancelado, no debe figurar como "pendiente de pago"
    final hasPending =
        !_isCancelled &&
        order.paymentStatus != 'PAID' &&
        order.pendingAmount > 0;
    final hasDiscount = order.discountAmount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isCancelled ? AppColors.dangerLight : AppColors.bg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isCancelled
                      ? Icons.remove_shopping_cart_rounded
                      : Icons.shopping_bag_outlined,
                  size: 16,
                  color: _isCancelled ? AppColors.danger : AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('d MMM yyyy', 'es').format(order.createdAt),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        decoration:
                            _isCancelled
                                ? TextDecoration.lineThrough
                                : null, // Tachado si está cancelado
                        color:
                            _isCancelled
                                ? AppColors.textMuted
                                : AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          _methodLabel(order.paymentMethod),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                        // Puntos ganados / usados (solo si no está cancelado)
                        if (!_isCancelled && order.pointsEarned > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '+${order.pointsEarned}pts',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.amber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (!_isCancelled && order.pointsUsed > 0) ...[
                          const SizedBox(width: 4),
                          Text(
                            '-${order.pointsUsed}pts',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    // Descuento
                    if (hasDiscount && !_isCancelled)
                      Text(
                        'Descuento: S/ ${order.discountAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.success,
                        ),
                      ),
                    // Vencimiento (solo si aplica crédito pendiente)
                    if (hasPending && order.dueDate != null)
                      Text(
                        'Vence: ${DateFormat('d MMM yyyy', 'es').format(order.dueDate!)}',
                        style: TextStyle(
                          fontSize: 10,
                          color:
                              order.dueDate!.isBefore(DateTime.now())
                                  ? AppColors.danger
                                  : Colors.orange,
                          fontWeight: FontWeight.w600,
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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      decoration:
                          _isCancelled
                              ? TextDecoration.lineThrough
                              : null, // Tachado si se canceló
                      color:
                          _isCancelled
                              ? AppColors.textMuted
                              : AppColors.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
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
                  // Monto pendiente (se oculta si el pedido está cancelado gracias a la corrección de hasPending)
                  if (hasPending)
                    Text(
                      'Debe S/ ${order.pendingAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ],
          ),
          // Separador sutil entre pedidos
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Divider(height: 1, color: AppColors.border),
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
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
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
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
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
