import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/providers/admin/customers_provider.dart'
    show CustomerSummary;

class TopProduct {
  final String productName;
  final int totalQuantity;
  final double totalSpent;

  TopProduct({
    required this.productName,
    required this.totalQuantity,
    required this.totalSpent,
  });
}

class RecentOrder {
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

  RecentOrder({
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

class UserAddress {
  final String addressLine;
  final String district;
  final String province;
  final String department;
  final String? reference;
  final bool isDefault;

  UserAddress({
    required this.addressLine,
    required this.district,
    required this.province,
    required this.department,
    this.reference,
    required this.isDefault,
  });
}

class CreditMovement {
  final String movementType; // 'CHARGE' | 'PAYMENT'
  final double amount;
  final String? paymentMethod;
  final String? notes;
  final DateTime createdAt;

  CreditMovement({
    required this.movementType,
    required this.amount,
    this.paymentMethod,
    this.notes,
    required this.createdAt,
  });
}

class CustomerDetailProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final CustomerSummary customer;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<TopProduct> _topProducts = [];
  List<TopProduct> get topProducts => _topProducts;

  List<RecentOrder> _recentOrders = [];
  List<RecentOrder> get recentOrders => _recentOrders;

  List<UserAddress> _addresses = [];
  List<UserAddress> get addresses => _addresses;

  List<CreditMovement> _creditMovements = [];
  List<CreditMovement> get creditMovements => _creditMovements;

  double _avgOrderValue = 0;
  double get avgOrderValue => _avgOrderValue;

  double _currentDebt = 0;
  double get currentDebt => _currentDebt;

  double _creditLimit = 0;
  double get creditLimit => _creditLimit;

  bool _hasCredit = false;
  bool get hasCredit => _hasCredit;

  bool _creditIsActive = false;
  bool get creditIsActive => _creditIsActive;

  String? _creditId;
  String? get creditId => _creditId;

  CustomerDetailProvider(this.customer);

  Future<void> loadAllData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadOrdersAndTopProducts(),
        _loadCredit(),
        _loadAddresses(),
      ]);
    } catch (e) {
      _errorMessage = 'Error al cargar los datos del cliente: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadOrdersAndTopProducts() async {
    final response = await _supabase
        .from('orders')
        .select(
          'id, created_at, total_amount, amount_paid, discount_amount, status, payment_status, payment_method, points_earned, points_used, due_date',
        )
        .eq('customer_id', customer.id)
        .order('created_at', ascending: false);

    final ordersResp = response as List;
    final orders =
        ordersResp
            .take(20)
            .map(
              (o) => RecentOrder(
                id: o['id'] as String,
                createdAt: DateTime.parse(o['created_at'] as String),
                totalAmount: (o['total_amount'] as num?)?.toDouble() ?? 0,
                amountPaid: (o['amount_paid'] as num?)?.toDouble() ?? 0,
                discountAmount: (o['discount_amount'] as num?)?.toDouble() ?? 0,
                status: o['status'] as String? ?? 'UNKNOWN',
                paymentStatus: o['payment_status'] as String? ?? 'UNKNOWN',
                paymentMethod: o['payment_method'] as String? ?? 'UNKNOWN',
                pointsEarned: (o['points_earned'] as num?)?.toInt() ?? 0,
                pointsUsed: (o['points_used'] as num?)?.toInt() ?? 0,
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

    _recentOrders = orders;
    _avgOrderValue = orders.isEmpty ? 0 : sum / orders.length;

    // TOP PRODUCTS logic
    final orderIds = ordersResp.map((o) => o['id'] as String).toList();
    if (orderIds.isEmpty) {
      _topProducts = [];
      return;
    }

    // Process in batches if there are too many orders to avoid long query
    List<dynamic> allItems = [];
    for (var i = 0; i < orderIds.length; i += 50) {
      final batchIds = orderIds.skip(i).take(50).toList();
      final itemsResp = await _supabase
          .from('order_items')
          .select('quantity, applied_price, products!inner(name)')
          .inFilter('order_id', batchIds);
      allItems.addAll(itemsResp);
    }

    final Map<String, _MutableProduct> agg = {};
    for (final item in allItems) {
      final pName =
          (item['products'] as Map?)?['name'] as String? ?? 'Producto';
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      final price = (item['applied_price'] as num?)?.toDouble() ?? 0;

      agg.putIfAbsent(pName, () => _MutableProduct());
      agg[pName]!.qty += qty;
      agg[pName]!.total += qty * price;
    }

    final sorted =
        agg.entries.toList()
          ..sort((a, b) => b.value.qty.compareTo(a.value.qty));
    _topProducts =
        sorted
            .take(5)
            .map(
              (e) => TopProduct(
                productName: e.key,
                totalQuantity: e.value.qty,
                totalSpent: e.value.total,
              ),
            )
            .toList();
  }

  Future<void> _loadCredit() async {
    final resp =
        await _supabase
            .from('customer_credits')
            .select('id, current_debt, credit_limit, is_active')
            .eq('profile_id', customer.id)
            .maybeSingle();

    if (resp != null) {
      _creditId = resp['id'] as String;
      _hasCredit = true;
      _creditIsActive = resp['is_active'] as bool? ?? false;
      _currentDebt = (resp['current_debt'] as num?)?.toDouble() ?? 0;
      _creditLimit = (resp['credit_limit'] as num?)?.toDouble() ?? 0;

      await _loadCreditMovements(_creditId!);
    } else {
      _hasCredit = false;
    }
  }

  Future<void> _loadCreditMovements(String creditId) async {
    final resp = await _supabase
        .from('customer_credit_movements')
        .select('movement_type, amount, payment_method, notes, created_at')
        .eq('credit_id', creditId)
        .order('created_at', ascending: false)
        .limit(10);

    _creditMovements =
        (resp as List)
            .map(
              (m) => CreditMovement(
                movementType: m['movement_type'] as String? ?? 'UNKNOWN',
                amount: (m['amount'] as num?)?.toDouble() ?? 0,
                paymentMethod: m['payment_method'] as String?,
                notes: m['notes'] as String?,
                createdAt: DateTime.parse(m['created_at'] as String),
              ),
            )
            .toList();
  }

  Future<void> _loadAddresses() async {
    final resp = await _supabase
        .from('user_addresses')
        .select(
          'address_line, district, province, department, reference, is_default',
        )
        .eq('profile_id', customer.id)
        .order('is_default', ascending: false);

    _addresses =
        (resp as List)
            .map(
              (a) => UserAddress(
                addressLine: a['address_line'] as String? ?? '',
                district: a['district'] as String? ?? '',
                province: a['province'] as String? ?? '',
                department: a['department'] as String? ?? '',
                reference: a['reference'] as String?,
                isDefault: a['is_default'] as bool? ?? false,
              ),
            )
            .toList();
  }
}

class _MutableProduct {
  int qty = 0;
  double total = 0;
}
