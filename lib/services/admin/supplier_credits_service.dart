import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/models/supplier_credit_models.dart';

class SupplierCreditsService {
  final _supabase = Supabase.instance.client;

  Future<
    ({
      List<SupplierCreditModel> accounts,
      int count,
      Map<String, dynamic> stats,
    })
  >
  fetchAccountsPaginated({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool withDebtOnly = false,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    // Calculamos las estadísticas primero sin rango
    var statsQuery = _supabase
        .from('supplier_credits')
        .select('*, suppliers!inner(name, tax_id, phone)');
    if (searchQuery.isNotEmpty) {
      statsQuery = statsQuery.or(
        'suppliers.name.ilike.%$searchQuery%,suppliers.tax_id.ilike.%$searchQuery%,suppliers.phone.ilike.%$searchQuery%',
      );
    }

    final statsResponse = await statsQuery;
    double totalDebt = 0;
    int activeCount = 0;
    int suspendedCount = 0;
    int maxedOutCount = 0;
    int debtCount = 0;

    for (final item in statsResponse as List) {
      final a = SupplierCreditModel.fromView(item);
      totalDebt += a.currentDebt;
      if (a.currentDebt > 0 && a.isActive) {
        debtCount++;
      }
      if (a.isActive) {
        activeCount++;
        if (a.isMaxedOut) maxedOutCount++;
      } else {
        suspendedCount++;
      }
    }

    // Ahora la consulta paginada
    var query = _supabase
        .from('supplier_credits')
        .select(
          'id, supplier_id, credit_limit, current_debt, is_active, suppliers!inner(name, tax_id, phone)',
        );

    if (searchQuery.isNotEmpty) {
      query = query.or(
        'suppliers.name.ilike.%$searchQuery%,suppliers.tax_id.ilike.%$searchQuery%,suppliers.phone.ilike.%$searchQuery%',
      );
    }

    if (withDebtOnly) {
      query = query.gt('current_debt', 0).eq('is_active', true);
    }

    final response = await query
        .order('current_debt', ascending: false)
        .range(from, to)
        .count(CountOption.exact);
    final count = response.count;
    final list =
        (response.data as List)
            .map((item) => SupplierCreditModel.fromView(item))
            .toList();

    return (
      accounts: list,
      count: count,
      stats: {
        'totalDebt': totalDebt,
        'activeAccounts': activeCount,
        'suspendedAccounts': suspendedCount,
        'maxedOutAccounts': maxedOutCount,
        'debtCount': debtCount,
      },
    );
  }

  Future<void> toggleAccountStatus(String creditId, bool currentStatus) async {
    await _supabase
        .from('supplier_credits')
        .update({
          'is_active': !currentStatus,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', creditId);
  }

  Future<void> saveAccount({
    required String? creditId,
    required String supplierId,
    required double creditLimit,
    String? adminProfileId,
  }) async {
    if (creditId != null) {
      await _supabase
          .from('supplier_credits')
          .update({
            'credit_limit': creditLimit,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', creditId);
    } else {
      await _supabase.from('supplier_credits').insert({
        'supplier_id': supplierId,
        'credit_limit': creditLimit,
        'current_debt': 0.0,
        'is_active': true,
      });
    }
  }

  Future<List<Map<String, dynamic>>> searchSuppliers(
    String query,
    Set<String> existingSupplierIds,
  ) async {
    final response = await _supabase
        .from('suppliers')
        .select('id, name, tax_id, phone')
        .eq('is_active', true)
        .or('name.ilike.%$query%,tax_id.ilike.%$query%,phone.ilike.%$query%')
        .limit(20);

    return (response as List)
        .cast<Map<String, dynamic>>()
        .where((p) => !existingSupplierIds.contains(p['id'] as String))
        .take(6)
        .toList();
  }

  Future<Set<String>> getExistingCreditSupplierIds({
    String? excludeSupplierId,
  }) async {
    final existingCredits = await _supabase
        .from('supplier_credits')
        .select('supplier_id');
    return (existingCredits as List)
        .map((e) => e['supplier_id'] as String)
        .where((id) => id != excludeSupplierId)
        .toSet();
  }

  Future<List<Map<String, dynamic>>> getPendingPurchaseOrders(
    String supplierId,
  ) async {
    return await _supabase
        .from('purchase_orders')
        .select('id, total_amount, amount_paid, payment_status, created_at')
        .eq('supplier_id', supplierId)
        .eq('payment_method', 'CRÉDITO')
        .inFilter('payment_status', ['PENDING', 'PARTIAL'])
        .inFilter('status', ['COMPLETED', 'RECEIVED'])
        .order('created_at', ascending: true);
  }

  Future<List<SupplierFinancialAccountOption>> getFinancialAccounts() async {
    final resp = await _supabase
        .from('financial_accounts')
        .select('id, name, type, balance')
        .eq('is_active', true)
        .order('name');

    const typeOrder = {'CAJA': 0, 'BANCO': 1, 'DIGITAL': 2, 'OTRO': 3};
    return (resp as List)
        .map(
          (a) => SupplierFinancialAccountOption(
            id: a['id'] as String,
            name: a['name'] as String,
            type: a['type'] as String,
            balance: (a['balance'] as num).toDouble(),
          ),
        )
        .toList()
      ..sort((a, b) {
        final oa = typeOrder[a.type] ?? 99;
        final ob = typeOrder[b.type] ?? 99;
        if (oa != ob) return oa.compareTo(ob);
        return a.name.compareTo(b.name);
      });
  }

  Future<Map<String, dynamic>?> getActiveCashShift(String accountId) async {
    return await _supabase
        .from('cash_shifts')
        .select('id, opened_at, opening_amount')
        .eq('account_id', accountId)
        .eq('status', 'OPEN')
        .maybeSingle();
  }

  Future<String?> getAdminProfileId() async {
    final authUserId = _supabase.auth.currentUser?.id;
    if (authUserId != null) {
      final resp =
          await _supabase
              .from('profiles')
              .select('id')
              .eq('auth_user_id', authUserId)
              .maybeSingle();
      if (resp != null) return resp['id'] as String;
    }
    return null;
  }

  Future<void> registerPayment({
    required SupplierCreditModel account,
    required double amount,
    required SupplierFinancialAccountOption selectedAccount,
    required String? selectedOrderId,
    required String notes,
    required List<Map<String, dynamic>> pendingOrders,
    required String? adminProfileId,
    required String? shiftId,
  }) async {
    // 1. Registro movimiento
    await _supabase.from('supplier_credit_movements').insert({
      'credit_id': account.creditId,
      if (selectedOrderId != null) 'order_id': selectedOrderId,
      'movement_type': 'PAYMENT',
      'amount': amount,
      'payment_method': selectedAccount.paymentMethodLabel,
      'notes': notes,
      if (adminProfileId != null) 'created_by': adminProfileId,
    });

    // 2. Aplicar a órdenes FIFO
    final ordersToApply =
        selectedOrderId != null
            ? pendingOrders.where((o) => o['id'] == selectedOrderId).toList()
            : List<Map<String, dynamic>>.from(pendingOrders);

    double remaining = amount;
    for (final order in ordersToApply) {
      if (remaining <= 0) break;
      final orderId = order['id'] as String;
      final total = (order['total_amount'] as num).toDouble();
      final alreadyPaid = (order['amount_paid'] as num).toDouble();
      final pendingOfOrder = (total - alreadyPaid).clamp(0.0, double.infinity);
      final toApply = remaining >= pendingOfOrder ? pendingOfOrder : remaining;
      final newAmountPaid = alreadyPaid + toApply;
      remaining -= toApply;

      final newPaymentStatus = newAmountPaid >= total ? 'PAID' : 'PARTIAL';

      await _supabase
          .from('purchase_orders')
          .update({
            'amount_paid': newAmountPaid,
            'payment_status': newPaymentStatus,
          })
          .eq('id', orderId);
    }

    // 3. Reducir deuda
    final newDebt = (account.currentDebt - amount).clamp(0.0, double.infinity);
    await _supabase
        .from('supplier_credits')
        .update({
          'current_debt': newDebt,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', account.creditId);

    // 4. Salida caja
    await _supabase.from('account_movements').insert({
      'account_id': selectedAccount.id,
      'movement_type': 'EXPENSE',
      'amount': amount,
      'description': 'Pago a crédito proveedor — ${account.supplierName}',
      'reference_type': 'supplier_credits',
      'reference_id': account.creditId,
      if (shiftId != null) 'shift_id': shiftId,
      if (adminProfileId != null) 'created_by': adminProfileId,
    });

    // 5. Saldo caja
    final newBalance = selectedAccount.balance - amount;
    await _supabase
        .from('financial_accounts')
        .update({'balance': newBalance})
        .eq('id', selectedAccount.id);
  }
}
