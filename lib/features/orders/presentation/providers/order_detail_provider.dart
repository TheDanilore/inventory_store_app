import 'package:flutter/foundation.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/orders/data/models/order_item_model.dart';
import 'package:inventory_store_app/features/orders/data/models/order_model.dart';
import 'package:inventory_store_app/features/orders/data/repositories/order_detail_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OrderDetailProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;
  final _service = OrderDetailService();

  OrderModel order;
  List<OrderItemModel> items = [];
  List<Map<String, dynamic>> profiles = [];
  List<Map<String, dynamic>> accounts = [];
  
  Map<String, List<Map<String, dynamic>>> batchesByVariant = {};
  Map<String, bool> usesBatchesMap = {};
  Map<String, List<BatchAssignmentModel>> batchOverrides = {};

  bool isLoading = true;
  bool hasError = false;
  bool isSaving = false;
  bool isReturning = false;
  bool wasModified = false;

  String? selectedCustomerId;
  String currentStatus = '';
  String paymentMethod = 'EFECTIVO';
  int pointsUsed = 0;
  int pointsEarned = 0;
  Map<String, dynamic>? creditInfo;

  OrderDetailProvider(this.order) {
    selectedCustomerId = order.customerId;
    currentStatus = order.status;
    pointsUsed = order.pointsUsed;
    pointsEarned = order.pointsEarned;
    paymentMethod = order.paymentMethod;
  }

  bool get isCompleted => currentStatus.toUpperCase() == 'COMPLETED';
  
  String? get updaterName {
    if (order.updatedBy == null) return null;
    try {
      final profile = profiles.firstWhere((p) => p['id'] == order.updatedBy);
      return profile['full_name'] as String?;
    } catch (_) {
      return null;
    }
  }

  bool get canToggleEdit => order.status.toUpperCase() == 'PENDING';

  Future<void> fetchData(String manualCustomerName) async {
    isLoading = true;
    hasError = false;
    notifyListeners();

    try {
      final futures = <Future>[
        _supabase
            .from('order_items')
            .select('''
          id, order_id, product_id, variant_id, quantity, unit_cost, applied_price, net_profit, created_at,
          products ( name, uses_batches, unit_cost, product_images(id, image_url, is_main, display_order, variant_id) ),
          product_variants ( sku, unit_cost, product_images(id, image_url, is_main, display_order), variant_attribute_values(attribute_values(id, value, attributes(id, name))) )
        ''')
            .eq('order_id', order.id),
        _supabase
            .from('profiles')
            .select('id, full_name, phone, document_number, role, is_active, wallet_balance')
            .eq('is_active', true)
            .order('full_name'),
        _supabase
            .from('financial_accounts')
            .select('id, name, type, balance')
            .eq('is_active', true)
            .order('name'),
        _supabase
            .from('orders')
            .select('*, profiles:customer_id(*)')
            .eq('id', order.id)
            .single(),
      ];

      if (selectedCustomerId != null) {
        futures.add(
          _supabase
              .from('customer_credits')
              .select('id, credit_limit, current_debt, is_active')
              .eq('profile_id', selectedCustomerId!)
              .maybeSingle(),
        );
      }

      final results = await Future.wait(futures);

      final itemsRaw = results[0] as List;
      final newItems = itemsRaw.map((row) {
        final variantId = row['variant_id'] as String?;
        final prod = row['products'] as Map<String, dynamic>?;
        final variant = row['product_variants'] as Map<String, dynamic>?;

        if (variantId != null && prod != null) {
          usesBatchesMap[variantId] = prod['uses_batches'] == true;
        }

        double resolvedUnitCost = 0.0;
        if (variant != null && variant['unit_cost'] != null && (variant['unit_cost'] as num) > 0) {
          resolvedUnitCost = (variant['unit_cost'] as num).toDouble();
        } else if (prod != null && prod['unit_cost'] != null) {
          resolvedUnitCost = (prod['unit_cost'] as num).toDouble();
        } else {
          resolvedUnitCost = (row['unit_cost'] as num?)?.toDouble() ?? 0.0;
        }
        row['unit_cost'] = resolvedUnitCost;
        return OrderItemModel.fromJson(Map<String, dynamic>.from(row));
      }).toList();

      List<Map<String, dynamic>> newProfiles = List<Map<String, dynamic>>.from(results[1]);
      List<Map<String, dynamic>> newAccounts = List<Map<String, dynamic>>.from(results[2]);
      
      final updatedOrderMap = results[3] as Map<String, dynamic>;
      final updatedOrder = OrderModel.fromJson(updatedOrderMap);

      const accountTypeOrder = {'CAJA': 0, 'BANCO': 1, 'DIGITAL': 2, 'OTRO': 3};
      newAccounts.sort((a, b) {
        final oa = accountTypeOrder[a['type'] as String? ?? ''] ?? 99;
        final ob = accountTypeOrder[b['type'] as String? ?? ''] ?? 99;
        if (oa != ob) return oa.compareTo(ob);
        return (a['name'] as String).compareTo(b['name'] as String);
      });

      final currentCustomerId = selectedCustomerId ?? order.customerId;
      if (currentCustomerId != null && !newProfiles.any((p) => p['id'] == currentCustomerId)) {
        try {
          final missingProfile = await _supabase
              .from('profiles')
              .select('id, full_name, phone, document_number, role, is_active, wallet_balance')
              .eq('id', currentCustomerId)
              .maybeSingle();
          if (missingProfile != null) newProfiles = [missingProfile, ...newProfiles];
        } catch (_) {}
      }

      order = updatedOrder;
      items = newItems;
      profiles = newProfiles;
      accounts = newAccounts;
      
      if (results.length > 4) {
        creditInfo = results[4] as Map<String, dynamic>?;
      }

      if (order.status.toUpperCase() == 'COMPLETED') {
        await _fetchBatchMovements();
      }

      isLoading = false;
      notifyListeners();
    } catch (e) {
      hasError = true;
      isLoading = false;
      notifyListeners();
      debugPrint('Error en fetchData OrderDetailProvider: $e');
    }
  }

  Future<void> _fetchBatchMovements() async {
    try {
      final movs = await _supabase
          .from('inventory_movements')
          .select('''
            variant_id, quantity,
            warehouse_stock_batches ( batch_number, expiry_date )
          ''')
          .eq('order_id', order.id)
          .eq('reason', 'SALE');

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final row in (movs as List)) {
        final variantId = row['variant_id'] as String? ?? '';
        final batch = row['warehouse_stock_batches'] as Map<String, dynamic>?;
        if (batch == null) continue;
        grouped.putIfAbsent(variantId, () => []).add({
          'batch_number': batch['batch_number'] ?? '',
          'expiry_date': batch['expiry_date'],
          'quantity': ((row['quantity'] as num?)?.toInt() ?? 0).abs(),
        });
      }
      batchesByVariant = grouped;
      notifyListeners();
    } catch (_) {}
  }

  void selectCustomer(String? customerId, double ratio, double earnRate) {
    selectedCustomerId = (customerId != null && customerId.isNotEmpty) ? customerId : null;
    creditInfo = null;
    pointsEarned = calculatePointsEarned(ratio, earnRate);
    notifyListeners();
    if (selectedCustomerId != null) {
      _loadCreditInfo(selectedCustomerId!);
    }
  }

  void updatePaymentMethod(String method, double ratio, double earnRate) {
    paymentMethod = method;
    if (method == 'CRÉDITO') {
      pointsUsed = 0;
    }
    pointsEarned = calculatePointsEarned(ratio, earnRate);
    notifyListeners();
  }

  void updateStatus(String status) {
    currentStatus = status;
    notifyListeners();
  }

  void resetEditState() {
    selectedCustomerId = order.customerId;
    currentStatus = order.status;
    pointsUsed = order.pointsUsed;
    pointsEarned = order.pointsEarned;
    paymentMethod = order.paymentMethod;
    notifyListeners();
  }

  Future<void> _loadCreditInfo(String profileId) async {
    try {
      final resp = await _supabase
          .from('customer_credits')
          .select('id, credit_limit, current_debt, is_active')
          .eq('profile_id', profileId)
          .maybeSingle();
      creditInfo = resp;
      notifyListeners();
    } catch (_) {}
  }

  double calculateOrderFinalAmount(double pointsToSolesRatio) {
    final subtotal = items.fold(0.0, (sum, i) => sum + i.subtotal);
    final discountAmount = order.discountAmount;
    double appliedDiscount = pointsUsed * pointsToSolesRatio;
    final maxDiscount = subtotal * 0.5;
    if (appliedDiscount > maxDiscount) appliedDiscount = maxDiscount;
    return (subtotal - appliedDiscount - discountAmount).clamp(0.0, double.infinity);
  }

  double calculateOrderTotalProfit() {
    double totalProfit = 0.0;
    for (final item in items) {
      totalProfit += (item.appliedPrice - item.unitCost) * item.quantity;
    }
    return totalProfit;
  }

  int calculatePointsEarned(double pointsToSolesRatio, double earningRate) {
    if (selectedCustomerId == null || items.isEmpty || paymentMethod == 'CRÉDITO') {
      return 0;
    }
    if (earningRate <= 0) return 0;
    
    final totalFinal = calculateOrderFinalAmount(pointsToSolesRatio);
    return (totalFinal * earningRate / pointsToSolesRatio).floor();
  }

  void updateItemQuantity(int idx, int qty, double ratio, double earnRate) {
    items[idx] = items[idx].copyWith(quantity: qty);
    pointsEarned = calculatePointsEarned(ratio, earnRate);
    batchOverrides.remove(items[idx].id);
    notifyListeners();
  }

  void updatePointsUsed(int pts, double ratio, double earnRate) {
    pointsUsed = pts;
    pointsEarned = calculatePointsEarned(ratio, earnRate);
    notifyListeners();
  }

  Future<List<BatchAssignmentModel>> fetchAvailableBatches(String variantId, String warehouseId) async {
    final resp = await _supabase
        .from('warehouse_stock_batches')
        .select('id, batch_number, expiry_date, available_quantity')
        .eq('variant_id', variantId)
        .eq('warehouse_id', warehouseId)
        .neq('batch_number', 'DEFAULT')
        .gt('available_quantity', 0)
        .order('expiry_date', ascending: true, nullsFirst: false);
        
    return (resp as List).map((row) => BatchAssignmentModel(
      batchId: row['id'] as String,
      batchNumber: row['batch_number'] as String,
      expiryDate: row['expiry_date'] != null ? DateTime.parse(row['expiry_date'] as String) : null,
      available: (row['available_quantity'] as num).toInt(),
      assigned: 0,
    )).toList();
  }

  void updateBatchOverrides(String itemId, List<BatchAssignmentModel> result) {
    batchOverrides[itemId] = result;
    notifyListeners();
  }

  Future<SaveOrderResult> saveChanges({
    required String? notesOverride,
    required String manualCustomerName,
    required double pointsToSolesRatio,
  }) async {
    isSaving = true;
    notifyListeners();

    try {
      final customerNameToSave = selectedCustomerId != null
          ? null
          : (manualCustomerName.trim().isEmpty ? null : manualCustomerName.trim());

      final result = await _service.saveOrderChanges(
        orderId: order.id,
        originalStatus: order.status,
        newStatus: currentStatus,
        paymentMethod: paymentMethod,
        selectedCustomerId: selectedCustomerId,
        customerNameToSave: customerNameToSave,
        items: items,
        pointsUsed: pointsUsed,
        pointsEarned: pointsEarned,
        totalAmount: calculateOrderFinalAmount(pointsToSolesRatio),
        totalProfit: calculateOrderTotalProfit(),
        batchOverrides: batchOverrides,
        notesOverride: notesOverride,
      );

      if (result.success) {
        wasModified = true;
      }
      return result;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }

  Future<SaveOrderResult> processReturn(String? notes) async {
    isReturning = true;
    notifyListeners();
    try {
      final result = await _service.processReturn(
        orderId: order.id,
        items: items,
        notesOverride: notes,
      );
      if (result.success) {
        wasModified = true;
      }
      return result;
    } finally {
      isReturning = false;
      notifyListeners();
    }
  }
}
