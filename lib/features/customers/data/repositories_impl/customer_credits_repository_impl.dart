import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/data/models/customer_credit_model.dart';
import 'package:inventory_store_app/features/customers/data/models/customer_credit_movement_model.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_list_result_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/customer_credits_repository.dart';

@LazySingleton(as: CustomerCreditsRepository)
class CustomerCreditsRepositoryImpl implements CustomerCreditsRepository {
  final SupabaseClient _supabase;

  CustomerCreditsRepositoryImpl() : _supabase = Supabase.instance.client;

  @override
  Future<CustomerCreditListResultEntity> getCreditAccounts({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  }) async {
    const selectFields = '''
      id,
      profile_id,
      credit_limit,
      current_debt,
      is_active,
      created_at,
      updated_at,
      profiles!customer_credits_profile_id_fkey ( id, full_name, phone, document_number, document_type )
    ''';

    var queryBuilder = _supabase.from('customer_credits').select(selectFields);
    var countBuilder = _supabase.from('customer_credits').select('id');

    if (query != null && query.isNotEmpty) {
      final profilesResp = await _supabase
          .from('profiles')
          .select('id')
          .or(
            'full_name.ilike.%$query%,document_number.ilike.%$query%,phone.ilike.%$query%',
          );
      final matchingProfileIds =
          (profilesResp as List).map((e) => e['id'] as String).toList();
      if (matchingProfileIds.isNotEmpty) {
        queryBuilder = queryBuilder.inFilter('profile_id', matchingProfileIds);
        countBuilder = countBuilder.inFilter('profile_id', matchingProfileIds);
      } else {
        queryBuilder = queryBuilder.eq(
          'profile_id',
          '00000000-0000-0000-0000-000000000000',
        );
        countBuilder = countBuilder.eq(
          'profile_id',
          '00000000-0000-0000-0000-000000000000',
        );
      }
    }

    if (showOnlyWithDebt) {
      queryBuilder = queryBuilder.gt('current_debt', 0);
      countBuilder = countBuilder.gt('current_debt', 0);
    }

    final countRes = await countBuilder;
    final totalCount = (countRes as List).length;

    final response = await queryBuilder.range(offset, offset + limit - 1);

    final accounts =
        (response as List)
            .map((e) => CreditAccountModel.fromJoin(e).toEntity())
            .toList();

    // Stats
    final statsResponse = await _supabase
        .from('customer_credits')
        .select('current_debt, is_active, credit_limit');

    double totalDebt = 0;
    int activeAccounts = 0;
    int suspendedAccounts = 0;
    int maxedOutAccounts = 0;

    for (var row in (statsResponse as List)) {
      final debt = (row['current_debt'] as num).toDouble();
      final creditLimit = (row['credit_limit'] as num).toDouble();
      final isActive = row['is_active'] as bool;

      totalDebt += debt;
      if (isActive) {
        activeAccounts++;
        if (creditLimit > 0 && debt >= creditLimit) {
          maxedOutAccounts++;
        }
      } else {
        suspendedAccounts++;
      }
    }

    return CustomerCreditListResultEntity(
      accounts: accounts,
      totalCount: totalCount,
      totalDebt: totalDebt,
      activeAccounts: activeAccounts,
      suspendedAccounts: suspendedAccounts,
      maxedOutAccounts: maxedOutAccounts,
    );
  }

  @override
  Future<CustomerCreditEntity?> getCreditAccountByCustomer(
    String customerId,
  ) async {
    final resp =
        await _supabase
            .from('customer_credits')
            .select('''
          id,
          profile_id,
          credit_limit,
          current_debt,
          is_active,
          created_at,
          updated_at,
          profiles!customer_credits_profile_id_fkey ( id, full_name, phone, document_number, document_type )
        ''')
            .eq('profile_id', customerId)
            .maybeSingle();

    if (resp != null) {
      return CreditAccountModel.fromJoin(resp).toEntity();
    }
    return null;
  }

  @override
  Future<CustomerCreditEntity> createCreditAccount({
    required String customerId,
    required double creditLimit,
  }) async {
    // Check if exists
    final exist =
        await _supabase
            .from('customer_credits')
            .select('id')
            .eq('profile_id', customerId)
            .maybeSingle();

    if (exist != null) {
      // Activar y actualizar
      await _supabase
          .from('customer_credits')
          .update({'is_active': true, 'credit_limit': creditLimit})
          .eq('profile_id', customerId);
    } else {
      await _supabase.from('customer_credits').insert({
        'profile_id': customerId,
        'credit_limit': creditLimit,
      });
    }

    final resp =
        await _supabase
            .from('customer_credits')
            .select('''
          id,
          profile_id,
          credit_limit,
          current_debt,
          is_active,
          created_at,
          updated_at,
          profiles!customer_credits_profile_id_fkey ( id, full_name, phone, document_number, document_type )
        ''')
            .eq('profile_id', customerId)
            .single();
    return CreditAccountModel.fromJoin(resp).toEntity();
  }

  @override
  Future<CustomerCreditEntity> updateCreditLimit({
    required String creditId,
    required double newLimit,
  }) async {
    await _supabase
        .from('customer_credits')
        .update({'credit_limit': newLimit})
        .eq('id', creditId);

    final resp =
        await _supabase
            .from('customer_credits')
            .select('''
          id,
          profile_id,
          credit_limit,
          current_debt,
          is_active,
          created_at,
          updated_at,
          profiles!customer_credits_profile_id_fkey ( id, full_name, phone, document_number, document_type )
        ''')
            .eq('id', creditId)
            .single();
    return CreditAccountModel.fromJoin(resp).toEntity();
  }

  @override
  Future<void> toggleCreditStatus(String creditId, bool isActive) async {
    await _supabase
        .from('customer_credits')
        .update({'is_active': isActive})
        .eq('id', creditId);
  }

  @override
  Future<List<CreditMovementEntity>> getCreditMovements({
    required String creditId,
    required int limit,
    required int offset,
    String? dateFilter,
  }) async {
    var query = _supabase
        .from('customer_credit_movements')
        .select()
        .eq('customer_credit_id', creditId);

    if (dateFilter != null && dateFilter != 'all') {
      final now = DateTime.now();
      if (dateFilter == '30_days') {
        final date = now.subtract(const Duration(days: 30)).toIso8601String();
        query = query.gte('created_at', date);
      } else if (dateFilter == 'this_month') {
        final date = DateTime(now.year, now.month, 1).toIso8601String();
        query = query.gte('created_at', date);
      }
    }

    final response = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((e) => CustomerCreditMovementModel.fromJson(e).toEntity())
        .toList();
  }

  @override
  Future<({double totalCharged, double totalPaid})> getCreditMovementsTotals({
    required String creditId,
    String? dateFilter,
  }) async {
    var query = _supabase
        .from('customer_credit_movements')
        .select('movement_type, amount')
        .eq('customer_credit_id', creditId);

    if (dateFilter != null && dateFilter != 'all') {
      final now = DateTime.now();
      if (dateFilter == '30_days') {
        final date = now.subtract(const Duration(days: 30)).toIso8601String();
        query = query.gte('created_at', date);
      } else if (dateFilter == 'this_month') {
        final date = DateTime(now.year, now.month, 1).toIso8601String();
        query = query.gte('created_at', date);
      }
    }

    final response = await query;
    double totalCharged = 0;
    double totalPaid = 0;
    for (var row in (response as List)) {
      final amount = (row['amount'] as num).toDouble();
      if (row['movement_type'] == 'CHARGE') {
        totalCharged += amount;
      } else {
        totalPaid += amount;
      }
    }

    return (totalCharged: totalCharged, totalPaid: totalPaid);
  }

  @override
  Future<void> registerPayment({
    required String customerId,
    required String creditId,
    required double amount,
    String? accountId,
    String? orderId,
    String? notes,
  }) async {
    await _supabase.rpc(
      'register_credit_payment_rpc',
      params: {
        'p_customer_id': customerId,
        'p_credit_id': creditId,
        'p_amount': amount,
        'p_account_id': accountId,
        'p_order_id': orderId,
        'p_notes': notes,
      },
    );
  }
}
