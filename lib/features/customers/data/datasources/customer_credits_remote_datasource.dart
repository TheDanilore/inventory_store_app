import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/app_exception.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/customers/data/models/customer_credit_model.dart';
import 'package:inventory_store_app/features/customers/data/models/customer_credit_movement_model.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_list_result_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

abstract class CustomerCreditsRemoteDataSource {
  Future<CustomerCreditListResultEntity> getCreditAccounts({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  });

  Future<CustomerCreditEntity?> getCreditAccountByCustomer(String customerId);

  Future<List<CustomerEntity>> searchCustomersWithoutCredit(
    String query, {
    int limit = 8,
  });

  Future<CustomerCreditEntity> createCreditAccount({
    required String customerId,
    required double creditLimit,
  });

  Future<CustomerCreditEntity> updateCreditLimit({
    required String creditId,
    required double newLimit,
  });

  Future<CustomerCreditEntity> toggleCreditStatus(
    String creditId,
    bool isActive,
  );

  Future<({List<CreditMovementEntity> items, int totalCount})>
  getCreditMovements({
    required String creditId,
    required int limit,
    required int offset,
    String? dateFilter,
    String? movementType,
  });

  Future<
    ({double totalCharged, double totalPaid, int chargeCount, int paymentCount})
  >
  getCreditMovementsTotals({required String creditId, String? dateFilter});

  Future<void> registerPayment({
    required String customerId,
    required String creditId,
    required double amount,
    String? accountId,
    String? orderId,
    String? notes,
    String? shiftId,
    String? idempotencyKey,
  });
}

@LazySingleton(as: CustomerCreditsRemoteDataSource)
class CustomerCreditsRemoteDataSourceImpl
    implements CustomerCreditsRemoteDataSource {
  final SupabaseClient _supabase;
  static const Duration _timeout = Duration(seconds: 15);
  static const String _tag = 'CUSTOMER_CREDITS_DS';

  static const String _selectCreditWithJoin = '''
    id,
    profile_id,
    customer_record_id,
    credit_limit,
    current_debt,
    is_active,
    created_at,
    updated_at,
    profiles:customers!customer_credits_customer_record_id_fkey ( id, full_name, phone, document_number, document_type )
  ''';

  static const String _selectCreditWithInnerJoin = '''
    id,
    profile_id,
    customer_record_id,
    credit_limit,
    current_debt,
    is_active,
    created_at,
    updated_at,
    profiles:customers!customer_credits_customer_record_id_fkey!inner ( id, full_name, phone, document_number, document_type )
  ''';

  CustomerCreditsRemoteDataSourceImpl(this._supabase);

  bool _isMissingRpc(PostgrestException e) {
    return e.code == 'PGRST202' ||
        e.code == '42883' ||
        e.message.contains('Could not find the function');
  }

  String _sanitizePostgrestToken(String input) {
    return input.trim().replaceAll(RegExp(r'[,()%]'), ' ').trim();
  }

  @override
  Future<CustomerCreditListResultEntity> getCreditAccounts({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  }) async {
    final cleanQuery = query?.trim() ?? '';

    try {
      final dynamic rpcRes = await _supabase
          .rpc(
            'get_customer_credits_page_rpc',
            params: {
              'p_search_query': cleanQuery,
              'p_with_debt_only': showOnlyWithDebt,
              'p_limit': limit,
              'p_offset': offset,
              'p_include_stats': true,
            },
          )
          .timeout(_timeout);

      final map = rpcRes as Map<String, dynamic>? ?? const {};
      final rawItems = (map['items'] as List<dynamic>?) ?? const [];
      final accounts = rawItems
          .map(
            (e) =>
                CreditAccountModel.fromRpc(
                  e as Map<String, dynamic>,
                ).toEntity(),
          )
          .toList(growable: false);
      final stats = (map['stats'] as Map<String, dynamic>?) ?? const {};
      final totalCount =
          (map['totalCount'] as num?)?.toInt() ?? accounts.length;

      return CustomerCreditListResultEntity(
        accounts: accounts,
        totalCount: totalCount,
        totalDebt: (stats['totalDebt'] as num?)?.toDouble() ?? 0.0,
        activeAccounts: (stats['activeAccounts'] as num?)?.toInt() ?? 0,
        suspendedAccounts: (stats['suspendedAccounts'] as num?)?.toInt() ?? 0,
        maxedOutAccounts: (stats['maxedOutAccounts'] as num?)?.toInt() ?? 0,
        debtCount: (stats['debtCount'] as num?)?.toInt() ?? 0,
      );
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'get_customer_credits_page_rpc no disponible; usando fallback PostgREST.',
        tag: _tag,
      );
      return _getCreditAccountsFallback(
        limit: limit,
        offset: offset,
        cleanQuery: cleanQuery,
        showOnlyWithDebt: showOnlyWithDebt,
      );
    }
  }

  Future<CustomerCreditListResultEntity> _getCreditAccountsFallback({
    required int limit,
    required int offset,
    required String cleanQuery,
    required bool showOnlyWithDebt,
  }) async {
    double totalDebt = 0;
    int activeAccounts = 0;
    int suspendedAccounts = 0;
    int maxedOutAccounts = 0;
    int debtCount = 0;

    try {
      final dynamic statsResult = await _supabase
          .rpc(
            'get_customer_credits_stats_rpc',
            params: {'p_search_query': cleanQuery},
          )
          .timeout(_timeout);
      if (statsResult is Map) {
        totalDebt = (statsResult['totalDebt'] as num?)?.toDouble() ?? 0.0;
        activeAccounts =
            (statsResult['activeAccounts'] as num?)?.toInt() ?? 0;
        suspendedAccounts =
            (statsResult['suspendedAccounts'] as num?)?.toInt() ?? 0;
        maxedOutAccounts =
            (statsResult['maxedOutAccounts'] as num?)?.toInt() ?? 0;
        debtCount = (statsResult['debtCount'] as num?)?.toInt() ?? 0;
      }
    } on PostgrestException catch (statsErr, st) {
      LoggerService.w(
        'get_customer_credits_stats_rpc falló en fallback',
        tag: _tag,
        error: statsErr,
        stackTrace: st,
      );
      final statsResponse = await _supabase
          .from('customer_credits')
          .select('current_debt, is_active, credit_limit')
          .timeout(_timeout);
      for (final row in (statsResponse as List<dynamic>)) {
        final r = row as Map<String, dynamic>;
        final debt = (r['current_debt'] as num?)?.toDouble() ?? 0.0;
        final creditLimit = (r['credit_limit'] as num?)?.toDouble() ?? 0.0;
        final isActive = r['is_active'] as bool? ?? false;

        totalDebt += debt;
        if (isActive) {
          activeAccounts++;
          if (debt > 0) debtCount++;
          if (creditLimit > 0 && debt >= creditLimit) {
            maxedOutAccounts++;
          }
        } else {
          suspendedAccounts++;
        }
      }
    }

    var queryBuilder = _supabase
        .from('customer_credits')
        .select(_selectCreditWithInnerJoin);

    final sanitized = _sanitizePostgrestToken(cleanQuery);
    if (sanitized.isNotEmpty) {
      queryBuilder = queryBuilder.or(
        'profiles.full_name.ilike.%$sanitized%,profiles.document_number.ilike.%$sanitized%,profiles.phone.ilike.%$sanitized%',
      );
    }

    if (showOnlyWithDebt) {
      queryBuilder = queryBuilder.gt('current_debt', 0);
    }

    final response = await queryBuilder
        .order('current_debt', ascending: false)
        .range(offset, offset + limit - 1)
        .count(CountOption.exact)
        .timeout(_timeout);

    final totalCount = response.count;
    final accounts = (response.data as List<dynamic>)
        .map(
          (e) =>
              CreditAccountModel.fromJoin(e as Map<String, dynamic>).toEntity(),
        )
        .toList(growable: false);

    return CustomerCreditListResultEntity(
      accounts: accounts,
      totalCount: totalCount,
      totalDebt: totalDebt,
      activeAccounts: activeAccounts,
      suspendedAccounts: suspendedAccounts,
      maxedOutAccounts: maxedOutAccounts,
      debtCount: debtCount,
    );
  }

  @override
  Future<CustomerCreditEntity?> getCreditAccountByCustomer(
    String customerId,
  ) async {
    final resp = await _supabase
        .from('customer_credits')
        .select(_selectCreditWithJoin)
        .or('customer_record_id.eq.$customerId,profile_id.eq.$customerId')
        .limit(1)
        .maybeSingle()
        .timeout(_timeout);

    if (resp != null) {
      return CreditAccountModel.fromJoin(resp).toEntity();
    }
    return null;
  }

  @override
  Future<List<CustomerEntity>> searchCustomersWithoutCredit(
    String query, {
    int limit = 8,
  }) async {
    final trimmed = query.trim();

    try {
      final dynamic rpcRes = await _supabase
          .rpc(
            'search_customers_without_credit_rpc',
            params: {'p_query': trimmed, 'p_limit': limit},
          )
          .timeout(_timeout);

      if (rpcRes is List) {
        return rpcRes
            .map((raw) {
              final row = raw as Map<String, dynamic>;
              return CustomerEntity(
                id: row['id'] as String,
                fullName: row['full_name'] as String? ?? 'Cliente',
                documentNumber: row['document_number'] as String?,
                documentType: row['document_type'] as String?,
                phone: row['phone'] as String?,
                isActive: true,
              );
            })
            .toList(growable: false);
      }
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'search_customers_without_credit_rpc no disponible; usando fallback sobre customers.',
        tag: _tag,
      );
    }

    var qb = _supabase
        .from('customers')
        .select('id, full_name, document_number, document_type, phone')
        .eq('is_active', true);

    final sanitized = _sanitizePostgrestToken(trimmed);
    if (sanitized.isNotEmpty) {
      qb = qb.or(
        'full_name.ilike.%$sanitized%,document_number.ilike.%$sanitized%,phone.ilike.%$sanitized%',
      );
    }

    final rows = await qb
        .order('full_name', ascending: true)
        .limit(limit)
        .timeout(_timeout);

    return (rows as List<dynamic>)
        .map((raw) {
          final row = raw as Map<String, dynamic>;
          return CustomerEntity(
            id: row['id'] as String,
            fullName: row['full_name'] as String? ?? 'Cliente',
            documentNumber: row['document_number'] as String?,
            documentType: row['document_type'] as String?,
            phone: row['phone'] as String?,
            isActive: true,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<CustomerCreditEntity> createCreditAccount({
    required String customerId,
    required double creditLimit,
  }) async {
    try {
      final dynamic rpcRes = await _supabase
          .rpc(
            'rpc_create_customer_credit',
            params: {
              'p_customer_id': customerId,
              'p_credit_limit': creditLimit,
            },
          )
          .timeout(_timeout);

      final map = rpcRes as Map<String, dynamic>?;
      if (map?['success'] == true && map?['account'] is Map<String, dynamic>) {
        return CreditAccountModel.fromRpc(
          map!['account'] as Map<String, dynamic>,
        ).toEntity();
      }
      if (map != null && map['error'] != null) {
        throw ServerException(message: map['error'].toString());
      }
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'rpc_create_customer_credit no disponible; usando fallback sobre customer_record_id.',
        tag: _tag,
      );
    }

    final exist = await _supabase
        .from('customer_credits')
        .select('id')
        .or('customer_record_id.eq.$customerId,profile_id.eq.$customerId')
        .limit(1)
        .maybeSingle()
        .timeout(_timeout);

    if (exist != null) {
      await _supabase
          .from('customer_credits')
          .update({
            'is_active': true,
            'credit_limit': creditLimit,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', exist['id'] as String)
          .timeout(_timeout);
    } else {
      await _supabase
          .from('customer_credits')
          .insert({
            'customer_record_id': customerId,
            'credit_limit': creditLimit,
            'current_debt': 0.0,
            'is_active': true,
          })
          .timeout(_timeout);
    }

    final resp = await _supabase
        .from('customer_credits')
        .select(_selectCreditWithJoin)
        .or('customer_record_id.eq.$customerId,profile_id.eq.$customerId')
        .limit(1)
        .single()
        .timeout(_timeout);

    return CreditAccountModel.fromJoin(resp).toEntity();
  }

  @override
  Future<CustomerCreditEntity> updateCreditLimit({
    required String creditId,
    required double newLimit,
  }) async {
    try {
      final dynamic rpcRes = await _supabase
          .rpc(
            'rpc_update_customer_credit_limit',
            params: {'p_credit_id': creditId, 'p_credit_limit': newLimit},
          )
          .timeout(_timeout);

      final map = rpcRes as Map<String, dynamic>?;
      if (map?['success'] == true && map?['account'] is Map<String, dynamic>) {
        return CreditAccountModel.fromRpc(
          map!['account'] as Map<String, dynamic>,
        ).toEntity();
      }
      if (map != null && map['error'] != null) {
        throw ServerException(message: map['error'].toString());
      }
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'rpc_update_customer_credit_limit no disponible; usando fallback.',
        tag: _tag,
      );
    }

    await _supabase
        .from('customer_credits')
        .update({
          'credit_limit': newLimit,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', creditId)
        .timeout(_timeout);

    final resp = await _supabase
        .from('customer_credits')
        .select(_selectCreditWithJoin)
        .eq('id', creditId)
        .single()
        .timeout(_timeout);

    return CreditAccountModel.fromJoin(resp).toEntity();
  }

  @override
  Future<CustomerCreditEntity> toggleCreditStatus(
    String creditId,
    bool isActive,
  ) async {
    try {
      final dynamic rpcRes = await _supabase
          .rpc(
            'rpc_toggle_customer_credit_status',
            params: {'p_credit_id': creditId, 'p_is_active': isActive},
          )
          .timeout(_timeout);

      final map = rpcRes as Map<String, dynamic>?;
      if (map?['success'] == true && map?['account'] is Map<String, dynamic>) {
        return CreditAccountModel.fromRpc(
          map!['account'] as Map<String, dynamic>,
        ).toEntity();
      }
      if (map != null && map['error'] != null) {
        throw ServerException(message: map['error'].toString());
      }
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'rpc_toggle_customer_credit_status no disponible; usando fallback.',
        tag: _tag,
      );
    }

    await _supabase
        .from('customer_credits')
        .update({
          'is_active': isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', creditId)
        .timeout(_timeout);

    final resp = await _supabase
        .from('customer_credits')
        .select(_selectCreditWithJoin)
        .eq('id', creditId)
        .single()
        .timeout(_timeout);

    return CreditAccountModel.fromJoin(resp).toEntity();
  }

  @override
  Future<({List<CreditMovementEntity> items, int totalCount})>
  getCreditMovements({
    required String creditId,
    required int limit,
    required int offset,
    String? dateFilter,
    String? movementType,
  }) async {
    try {
      var query = _supabase
          .from('customer_credit_movements_summary')
          .select()
          .eq('customer_credit_id', creditId);

      if (movementType != null && movementType != 'ALL') {
        query = query.eq('movement_type', movementType);
      }

      if (dateFilter != null && dateFilter != 'all') {
        final now = DateTime.now();
        if (dateFilter == '30_days') {
          final date =
              now.subtract(const Duration(days: 30)).toUtc().toIso8601String();
          query = query.gte('created_at', date);
        } else if (dateFilter == 'this_month') {
          final date = DateTime(now.year, now.month, 1).toUtc().toIso8601String();
          query = query.gte('created_at', date);
        }
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1)
          .count(CountOption.exact)
          .timeout(_timeout);

      final items = (response.data as List<dynamic>)
          .map(
            (e) =>
                CustomerCreditMovementModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ).toEntity(),
          )
          .toList(growable: false);

      return (items: items, totalCount: response.count);
    } catch (viewErr, st) {
      LoggerService.w(
        'customer_credit_movements_summary falló, intentando joins directos',
        tag: _tag,
        error: viewErr,
        stackTrace: st,
      );

      var fbQuery = _supabase
          .from('customer_credit_movements')
          .select('''
            id,
            customer_credit_id,
            order_id,
            movement_type,
            amount,
            payment_method,
            notes,
            created_at,
            created_by,
            creator:profiles!customer_credit_movements_created_by_fkey ( full_name ),
            orders!customer_credit_movements_order_id_fkey ( id, customer_name, payment_method, total_amount )
          ''')
          .eq('customer_credit_id', creditId);

      if (movementType != null && movementType != 'ALL') {
        fbQuery = fbQuery.eq('movement_type', movementType);
      }

      if (dateFilter != null && dateFilter != 'all') {
        final now = DateTime.now();
        if (dateFilter == '30_days') {
          final date =
              now.subtract(const Duration(days: 30)).toUtc().toIso8601String();
          fbQuery = fbQuery.gte('created_at', date);
        } else if (dateFilter == 'this_month') {
          final date = DateTime(now.year, now.month, 1).toUtc().toIso8601String();
          fbQuery = fbQuery.gte('created_at', date);
        }
      }

      final fbResponse = await fbQuery
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1)
          .count(CountOption.exact)
          .timeout(_timeout);

      final items = (fbResponse.data as List<dynamic>)
          .map(
            (e) =>
                CustomerCreditMovementModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ).toEntity(),
          )
          .toList(growable: false);

      return (items: items, totalCount: fbResponse.count);
    }
  }

  @override
  Future<
    ({double totalCharged, double totalPaid, int chargeCount, int paymentCount})
  >
  getCreditMovementsTotals({
    required String creditId,
    String? dateFilter,
  }) async {
    try {
      final dynamic rpcRes = await _supabase
          .rpc(
            'get_credit_movements_totals_rpc',
            params: {'p_credit_id': creditId, 'p_date_filter': dateFilter},
          )
          .timeout(_timeout);

      if (rpcRes is List && rpcRes.isNotEmpty) {
        final row = rpcRes.first as Map;
        return (
          totalCharged: (row['total_charged'] as num?)?.toDouble() ?? 0.0,
          totalPaid: (row['total_paid'] as num?)?.toDouble() ?? 0.0,
          chargeCount: (row['charge_count'] as num?)?.toInt() ?? 0,
          paymentCount: (row['payment_count'] as num?)?.toInt() ?? 0,
        );
      }
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'get_credit_movements_totals_rpc no disponible; usando fallback tabla.',
        tag: _tag,
      );
    }

    var query = _supabase
        .from('customer_credit_movements')
        .select('movement_type, amount')
        .eq('customer_credit_id', creditId);

    if (dateFilter != null && dateFilter != 'all') {
      final now = DateTime.now();
      if (dateFilter == '30_days') {
        final date =
            now.subtract(const Duration(days: 30)).toUtc().toIso8601String();
        query = query.gte('created_at', date);
      } else if (dateFilter == 'this_month') {
        final date = DateTime(now.year, now.month, 1).toUtc().toIso8601String();
        query = query.gte('created_at', date);
      }
    }

    final response = await query.timeout(_timeout);
    double totalCharged = 0;
    double totalPaid = 0;
    int chargeCount = 0;
    int paymentCount = 0;
    for (final raw in (response as List<dynamic>)) {
      final row = raw as Map<String, dynamic>;
      final amount = (row['amount'] as num?)?.toDouble() ?? 0.0;
      if (row['movement_type'] == 'CHARGE') {
        totalCharged += amount;
        chargeCount++;
      } else {
        totalPaid += amount;
        paymentCount++;
      }
    }

    return (
      totalCharged: totalCharged,
      totalPaid: totalPaid,
      chargeCount: chargeCount,
      paymentCount: paymentCount,
    );
  }

  @override
  Future<void> registerPayment({
    required String customerId,
    required String creditId,
    required double amount,
    String? accountId,
    String? orderId,
    String? notes,
    String? shiftId,
    String? idempotencyKey,
  }) async {
    dynamic response;
    final baseParams = {
      'p_customer_id': customerId,
      'p_credit_id': creditId.isNotEmpty ? creditId : null,
      'p_amount': amount,
      'p_account_id': accountId,
      'p_order_id': orderId,
      'p_notes': notes,
      'p_shift_id': shiftId,
    };

    try {
      response = await _supabase
          .rpc(
            'register_credit_payment_rpc',
            params: {
              ...baseParams,
              if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
            },
          )
          .timeout(_timeout);
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e) || idempotencyKey == null) rethrow;
      LoggerService.w(
        'register_credit_payment_rpc legado (7 args) detectado; reintentando sin p_idempotency_key.',
        tag: _tag,
      );
      response = await _supabase
          .rpc('register_credit_payment_rpc', params: baseParams)
          .timeout(_timeout);
    }

    final result = response as Map<String, dynamic>?;
    if (result?['success'] == true) return;

    final errMsg =
        result?['error'] as String? ??
        result?['detail'] as String? ??
        'Error desconocido del servidor al registrar abono.';
    final detailCode = result?['detail']?.toString();
    if (detailCode == '42501') {
      throw UnauthorizedException(message: errMsg);
    }
    if (detailCode == 'P0001') {
      throw ValidationException(message: errMsg);
    }
    if (detailCode == 'P0002') {
      throw NotFoundException(message: errMsg);
    }
    throw ServerException(message: errMsg, code: detailCode);
  }
}
