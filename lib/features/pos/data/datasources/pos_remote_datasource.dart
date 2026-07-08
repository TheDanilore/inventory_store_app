import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';

abstract class PosRemoteDataSource {
  Future<List<WarehouseModel>> fetchActiveWarehouses();
  Future<List<Map<String, dynamic>>> fetchActiveAccounts();
  Future<Map<String, dynamic>?> fetchActiveShift(String accountId);
  Future<List<Map<String, dynamic>>> searchClients(String text);
  Future<Map<String, dynamic>?> fetchClientCredit(String clientId);
  Future<List<BatchAssignmentModel>> fetchBatchesForVariant(String variantId, String warehouseId);
  Future<List<Map<String, dynamic>>> fetchStockBatches(String variantId, String warehouseId);
  Future<Map<String, dynamic>> getCurrentProfile();
  
  // Para la venta
  Future<String> createOrder(Map<String, dynamic> orderData);
  Future<void> createOrderItems(List<Map<String, dynamic>> itemsData);
  Future<void> updateBatchQuantities(List<Map<String, dynamic>> batchUpdates);
  Future<void> createInventoryMovements(List<Map<String, dynamic>> movements);
  Future<void> createAccountMovement(Map<String, dynamic> movementData);
  Future<void> updateAccountBalance(String accountId, double newBalance);
  Future<Map<String, dynamic>> fetchProfileWallet(String profileId);
  Future<void> updateProfileWallet(String profileId, int newBalance);
  Future<void> createWalletMovement(Map<String, dynamic> movementData);
  Future<Map<String, dynamic>> fetchLatestCustomerCredit(String profileId);
  Future<void> updateCustomerCredit(String creditId, double newDebt);
  Future<void> createCustomerCreditMovement(Map<String, dynamic> movementData);
}

class PosRemoteDataSourceImpl implements PosRemoteDataSource {
  final SupabaseClient _supabase;

  PosRemoteDataSourceImpl({SupabaseClient? supabaseClient})
      : _supabase = supabaseClient ?? Supabase.instance.client;

  @override
  Future<List<WarehouseModel>> fetchActiveWarehouses() async {
    final res = await _supabase
        .from('warehouses')
        .select('id, name')
        .eq('is_active', true)
        .order('name');
    return (res as List).map((w) => WarehouseModel.fromJson(w)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchActiveAccounts() async {
    final res = await _supabase
        .from('financial_accounts')
        .select('id, name, type, balance')
        .eq('is_active', true)
        .order('type')
        .order('name');
    return List<Map<String, dynamic>>.from(res);
  }

  @override
  Future<Map<String, dynamic>?> fetchActiveShift(String accountId) async {
    return await _supabase
        .from('cash_shifts')
        .select('id, status, opening_amount, opened_at, expected_amount, actual_amount, difference_amount, notes, closed_at, account_id')
        .eq('account_id', accountId)
        .eq('status', 'OPEN')
        .maybeSingle();
  }

  @override
  Future<List<Map<String, dynamic>>> searchClients(String text) async {
    final response = await _supabase
        .from('profiles')
        .select('id, full_name, phone, document_number, wallet_balance, role, is_active')
        .eq('is_active', true)
        .or('full_name.ilike.%$text%,document_number.ilike.%$text%,phone.ilike.%$text%')
        .limit(10);
    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<Map<String, dynamic>?> fetchClientCredit(String clientId) async {
    return await _supabase
        .from('customer_credits')
        .select('id, credit_limit, current_debt, is_active')
        .eq('profile_id', clientId)
        .maybeSingle();
  }

  @override
  Future<List<BatchAssignmentModel>> fetchBatchesForVariant(String variantId, String warehouseId) async {
    final resp = await _supabase
        .from('warehouse_stock_batches')
        .select('id, batch_number, expiry_date, available_quantity')
        .eq('variant_id', variantId)
        .eq('warehouse_id', warehouseId)
        .gt('available_quantity', 0)
        .order('expiry_date', ascending: true, nullsFirst: false);

    return (resp as List).map((b) {
      return BatchAssignmentModel(
        batchId: b['id'] as String,
        batchNumber: b['batch_number'] as String,
        expiryDate: b['expiry_date'] != null ? DateTime.tryParse(b['expiry_date'] as String) : null,
        available: (b['available_quantity'] as num).toInt(),
        assigned: 0,
      );
    }).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchStockBatches(String variantId, String warehouseId) async {
    final resp = await _supabase
        .from('warehouse_stock_batches')
        .select('id, available_quantity, batch_number, expiry_date')
        .eq('variant_id', variantId)
        .eq('warehouse_id', warehouseId)
        .gt('available_quantity', 0)
        .order('expiry_date', ascending: true, nullsFirst: false);
    return List<Map<String, dynamic>>.from(resp);
  }

  @override
  Future<Map<String, dynamic>> getCurrentProfile() async {
    final authUserId = _supabase.auth.currentUser?.id;
    if (authUserId == null) throw Exception('No hay usuario autenticado');
    return await _supabase
        .from('profiles')
        .select('id')
        .eq('auth_user_id', authUserId)
        .single();
  }

  @override
  Future<String> createOrder(Map<String, dynamic> orderData) async {
    final orderResp = await _supabase.from('orders').insert(orderData).select('id').single();
    return orderResp['id'] as String;
  }

  @override
  Future<void> createOrderItems(List<Map<String, dynamic>> itemsData) async {
    await _supabase.from('order_items').insert(itemsData);
  }

  @override
  Future<void> updateBatchQuantities(List<Map<String, dynamic>> batchUpdates) async {
    for (final up in batchUpdates) {
      await _supabase
          .from('warehouse_stock_batches')
          .update({'available_quantity': up['new_quantity']})
          .eq('id', up['id']);
    }
  }

  @override
  Future<void> createInventoryMovements(List<Map<String, dynamic>> movements) async {
    await _supabase.from('inventory_movements').insert(movements);
  }

  @override
  Future<void> createAccountMovement(Map<String, dynamic> movementData) async {
    await _supabase.from('account_movements').insert(movementData);
  }

  @override
  Future<void> updateAccountBalance(String accountId, double newBalance) async {
    await _supabase.from('financial_accounts').update({'balance': newBalance}).eq('id', accountId);
  }

  @override
  Future<Map<String, dynamic>> fetchProfileWallet(String profileId) async {
    return await _supabase.from('profiles').select('wallet_balance').eq('id', profileId).single();
  }

  @override
  Future<void> updateProfileWallet(String profileId, int newBalance) async {
    await _supabase.from('profiles').update({'wallet_balance': newBalance}).eq('id', profileId);
  }

  @override
  Future<void> createWalletMovement(Map<String, dynamic> movementData) async {
    await _supabase.from('wallet_movements').insert(movementData);
  }

  @override
  Future<Map<String, dynamic>> fetchLatestCustomerCredit(String profileId) async {
    return await _supabase
        .from('customer_credits')
        .select('id, current_debt')
        .eq('profile_id', profileId)
        .single();
  }

  @override
  Future<void> updateCustomerCredit(String creditId, double newDebt) async {
    await _supabase
        .from('customer_credits')
        .update({'current_debt': newDebt, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', creditId);
  }

  @override
  Future<void> createCustomerCreditMovement(Map<String, dynamic> movementData) async {
    await _supabase.from('customer_credit_movements').insert(movementData);
  }
}
