import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customers_global_stats_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customers_page_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/recent_order_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/top_product_entity.dart';

abstract class CustomersRemoteDataSource {
  Future<CustomersPageEntity> getCustomersPage({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  });

  Future<CustomerEntity> getCustomerDetail(String customerId);

  Future<CustomerEntity> createCustomer({
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
  });

  Future<CustomerEntity> updateCustomer({
    required String customerId,
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
    bool? isActive,
  });

  Future<void> saveCustomerFullProfile({
    String? customerId,
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
    required bool isActive,
    required int walletAdjustDelta,
    required double currentWalletBalance,
    required bool hasCredit,
    required bool creditExistsInDb,
    String? creditId,
    required bool creditIsActive,
    required double newCreditLimit,
  });

  Future<void> toggleCustomerStatus(String customerId, bool isActive);

  Future<CustomersGlobalStatsEntity> getGlobalStats();

  Future<List<CustomerEntity>> getTopCustomers(
    int limit, {
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<RecentOrderEntity>> getCustomerRecentOrders(String customerId);

  Future<List<TopProductEntity>> getCustomerTopProducts(String customerId);
}

@LazySingleton(as: CustomersRemoteDataSource)
class CustomersRemoteDataSourceImpl implements CustomersRemoteDataSource {
  final SupabaseClient _supabase;
  static const Duration _timeout = Duration(seconds: 15);
  static const String _tag = 'CUSTOMERS_DS';
  static const String _customerSelectColumns =
      'id, profile_id, full_name, phone, document_number, document_type, avatar_url, is_active, wallet_balance, created_at';

  CustomersRemoteDataSourceImpl(this._supabase);

  bool _isMissingRpc(PostgrestException e) {
    return e.code == 'PGRST202' ||
        e.code == '42883' ||
        e.message.contains('Could not find the function');
  }

  String _sanitizePostgrestToken(String input) {
    return input.trim().replaceAll(RegExp(r'[,()%]'), ' ').trim();
  }

  CustomerEntity _mapCustomerRow(
    Map<String, dynamic> row, {
    double? overrideDebt,
    double? overrideCreditLimit,
    double? overrideRevenue,
    int? overrideOrderCount,
    DateTime? overrideLastOrderAt,
    int? overrideLocationsCount,
  }) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    return CustomerEntity(
      id: row['id'] as String,
      fullName: row['full_name'] as String? ?? 'Cliente',
      phone: row['phone'] as String?,
      documentNumber: row['document_number'] as String?,
      documentType: row['document_type'] as String?,
      avatarUrl: row['avatar_url'] as String?,
      walletBalance: (row['wallet_balance'] as num?)?.toDouble() ?? 0.0,
      isActive: row['is_active'] as bool? ?? true,
      createdAt: parseDate(row['created_at']),
      currentDebt:
          overrideDebt ?? (row['current_debt'] as num?)?.toDouble() ?? 0.0,
      creditLimit:
          overrideCreditLimit ??
          (row['credit_limit'] as num?)?.toDouble() ??
          0.0,
      totalRevenue:
          overrideRevenue ??
          (row['total_revenue'] ?? row['totalRevenue'] ?? row['total_spent']
                  as num?)
              ?.toDouble() ??
          0.0,
      orderCount:
          overrideOrderCount ??
          (row['order_count'] ?? row['orderCount'] as num?)?.toInt() ??
          0,
      lastOrderAt: overrideLastOrderAt ?? parseDate(row['last_order_at']),
      locationsCount:
          overrideLocationsCount ??
          (row['locations_count'] as num?)?.toInt() ??
          0,
    );
  }

  @override
  Future<CustomersPageEntity> getCustomersPage({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  }) async {
    final trimmed = query?.trim() ?? '';

    try {
      final dynamic rpcRes = await _supabase
          .rpc(
            'get_customers_page_rpc',
            params: {
              'p_search_query': trimmed,
              'p_only_with_debt': showOnlyWithDebt,
              'p_limit': limit,
              'p_offset': offset,
            },
          )
          .timeout(_timeout);

      final map = rpcRes as Map<String, dynamic>? ?? const {};
      final rawItems = (map['items'] as List<dynamic>?) ?? const [];
      final customers = rawItems
          .map((item) => _mapCustomerRow(item as Map<String, dynamic>))
          .toList(growable: false);
      final totalCount = (map['totalCount'] as num?)?.toInt() ?? customers.length;
      final hasMore =
          customers.length >= limit &&
          (offset + customers.length) < totalCount;

      return CustomersPageEntity(
        customers: customers,
        totalCount: totalCount,
        hasMore: hasMore,
      );
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'get_customers_page_rpc no disponible aún; usando fallback PostgREST.',
        tag: _tag,
      );
      return _getCustomersPageFallback(
        limit: limit,
        offset: offset,
        query: trimmed,
        showOnlyWithDebt: showOnlyWithDebt,
      );
    }
  }

  Future<CustomersPageEntity> _getCustomersPageFallback({
    required int limit,
    required int offset,
    required String query,
    required bool showOnlyWithDebt,
  }) async {
    dynamic queryBuilder = _supabase
        .from('customers')
        .select(
          '$_customerSelectColumns, customer_credits:customer_credits!customer_credits_customer_record_id_fkey${showOnlyWithDebt ? "!inner" : ""}(id, current_debt, credit_limit, is_active)',
        );

    final sanitized = _sanitizePostgrestToken(query);
    if (sanitized.isNotEmpty) {
      queryBuilder = queryBuilder.or(
        'full_name.ilike.%$sanitized%,document_number.ilike.%$sanitized%,phone.ilike.%$sanitized%',
      );
    }

    if (showOnlyWithDebt) {
      queryBuilder = queryBuilder.gt('customer_credits.current_debt', 0);
    }

    if (sanitized.isEmpty) {
      queryBuilder = queryBuilder.order('created_at', ascending: false);
    }

    final response = await queryBuilder
        .range(offset, offset + limit - 1)
        .count(CountOption.exact)
        .timeout(_timeout);

    final res = (response.data as List<dynamic>?) ?? const [];
    final totalCount = response.count as int;
    if (res.isEmpty) {
      return CustomersPageEntity(
        customers: const [],
        totalCount: totalCount,
        hasMore: false,
      );
    }

    final cIds = res.map((e) => e['id'] as String).toList(growable: false);

    final ordersFuture = _supabase
        .from('orders')
        .select('customer_record_id, total_amount, created_at')
        .eq('status', 'COMPLETED')
        .inFilter('customer_record_id', cIds)
        .timeout(_timeout);

    final locFuture = _supabase
        .from('customer_locations')
        .select('customer_record_id')
        .inFilter('customer_record_id', cIds)
        .timeout(_timeout);

    final queryResults = await Future.wait([
      ordersFuture,
      locFuture.catchError((err, st) {
        LoggerService.w(
          'Aviso: no se pudieron cargar conteos de ubicación de clientes',
          tag: _tag,
          error: err,
          stackTrace: st,
        );
        return <Map<String, dynamic>>[];
      }),
    ]);

    final ordersRes = queryResults[0] as List<dynamic>;
    final locRes = queryResults[1] as List<dynamic>;

    final revenueById = <String, double>{};
    final countById = <String, int>{};
    final lastOrderById = <String, DateTime>{};
    for (final raw in ordersRes) {
      final row = raw as Map<String, dynamic>;
      final cid = row['customer_record_id'] as String?;
      if (cid == null) continue;
      revenueById[cid] =
          (revenueById[cid] ?? 0.0) +
          ((row['total_amount'] as num?)?.toDouble() ?? 0.0);
      countById[cid] = (countById[cid] ?? 0) + 1;
      final dt =
          row['created_at'] != null
              ? DateTime.tryParse(row['created_at'].toString())
              : null;
      if (dt != null &&
          (lastOrderById[cid] == null || dt.isAfter(lastOrderById[cid]!))) {
        lastOrderById[cid] = dt;
      }
    }

    final locCounts = <String, int>{};
    for (final raw in locRes) {
      final pid = (raw as Map<String, dynamic>)['customer_record_id'] as String?;
      if (pid != null) {
        locCounts[pid] = (locCounts[pid] ?? 0) + 1;
      }
    }

    final customers = res.map<CustomerEntity>((raw) {
      final json = raw as Map<String, dynamic>;
      final id = json['id'] as String;

      double currentDebt = 0.0;
      double creditLimit = 0.0;
      final creditData = json['customer_credits'];
      Map<String, dynamic>? creditObj;
      if (creditData is Map<String, dynamic>) {
        creditObj = creditData;
      } else if (creditData is List && creditData.isNotEmpty) {
        creditObj = creditData.first as Map<String, dynamic>?;
      }
      if (creditObj != null) {
        currentDebt = (creditObj['current_debt'] as num?)?.toDouble() ?? 0.0;
        creditLimit = (creditObj['credit_limit'] as num?)?.toDouble() ?? 0.0;
      }

      return _mapCustomerRow(
        json,
        overrideDebt: currentDebt,
        overrideCreditLimit: creditLimit,
        overrideRevenue: revenueById[id] ?? 0.0,
        overrideOrderCount: countById[id] ?? 0,
        overrideLastOrderAt: lastOrderById[id],
        overrideLocationsCount: locCounts[id] ?? 0,
      );
    }).toList(growable: false);

    return CustomersPageEntity(
      customers: customers,
      totalCount: totalCount,
      hasMore:
          customers.length >= limit &&
          (offset + customers.length) < totalCount,
    );
  }

  @override
  Future<CustomerEntity> getCustomerDetail(String customerId) async {
    final res = await _supabase
        .from('customers')
        .select(_customerSelectColumns)
        .eq('id', customerId)
        .single()
        .timeout(_timeout);

    final profileId = res['profile_id'] as String?;
    final ordersFilter =
        profileId != null
            ? 'customer_record_id.eq.$customerId,customer_id.eq.$profileId'
            : 'customer_record_id.eq.$customerId';

    final ordersRes = await _supabase
        .from('orders')
        .select('total_amount, created_at')
        .or(ordersFilter)
        .eq('status', 'COMPLETED')
        .timeout(_timeout);

    final creditRes = await _supabase
        .from('customer_credits')
        .select('current_debt, credit_limit')
        .eq('customer_record_id', customerId)
        .maybeSingle()
        .timeout(_timeout);

    double totalSpent = 0.0;
    DateTime? lastOrderAt;
    for (final row in ordersRes) {
      totalSpent += (row['total_amount'] as num?)?.toDouble() ?? 0.0;
      final dt =
          row['created_at'] != null
              ? DateTime.tryParse(row['created_at'].toString())
              : null;
      if (dt != null && (lastOrderAt == null || dt.isAfter(lastOrderAt))) {
        lastOrderAt = dt;
      }
    }

    final currentDebt = (creditRes?['current_debt'] as num?)?.toDouble() ?? 0.0;
    final creditLimit = (creditRes?['credit_limit'] as num?)?.toDouble() ?? 0.0;

    int locCount = 0;
    try {
      final locRes = await _supabase
          .from('customer_locations')
          .select('id')
          .eq('customer_record_id', customerId)
          .timeout(_timeout);
      locCount = (locRes as List).length;
    } catch (e, st) {
      LoggerService.w(
        'No se pudo obtener conteo de ubicaciones para $customerId',
        tag: _tag,
        error: e,
        stackTrace: st,
      );
    }

    return _mapCustomerRow(
      res,
      overrideDebt: currentDebt,
      overrideCreditLimit: creditLimit,
      overrideRevenue: totalSpent,
      overrideOrderCount: ordersRes.length,
      overrideLastOrderAt: lastOrderAt,
      overrideLocationsCount: locCount,
    );
  }

  @override
  Future<CustomerEntity> createCustomer({
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
  }) async {
    final cleanName = fullName.trim();
    final cleanPhone =
        (phone != null && phone.trim().isNotEmpty) ? phone.trim() : null;
    final cleanDoc =
        (documentNumber != null && documentNumber.trim().isNotEmpty)
            ? documentNumber.trim()
            : null;
    final cleanDocType = documentType ?? 'DNI';

    try {
      final dynamic rpcResp = await _supabase
          .rpc(
            'save_customer_full_profile_rpc',
            params: {
              'p_full_name': cleanName,
              'p_phone': cleanPhone,
              'p_document_number': cleanDoc,
              'p_document_type': cleanDocType,
              'p_is_active': true,
              'p_wallet_delta': 0,
              'p_has_credit': true,
              'p_credit_limit': 0.0,
            },
          )
          .timeout(_timeout);

      if (rpcResp is Map<String, dynamic>) {
        final newId =
            (rpcResp['customer_id'] ?? rpcResp['profile_id']) as String?;
        if (newId != null && newId.isNotEmpty) {
          return await getCustomerDetail(newId);
        }
      }
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'save_customer_full_profile_rpc no disponible en createCustomer; usando fallback sobre customers.',
        tag: _tag,
      );
    }

    final custType = cleanDocType == 'RUC' ? 'COMPANY' : 'PERSON';
    const validDocTypes = {'DNI', 'RUC', 'CE', 'PASAPORTE'};
    final normDocType =
        validDocTypes.contains(cleanDocType) ? cleanDocType : 'OTRO';

    final res = await _supabase
        .from('customers')
        .insert({
          'customer_type': custType,
          'full_name': cleanName,
          'is_active': true,
          'document_type': normDocType,
          if (cleanPhone != null) 'phone': cleanPhone,
          if (cleanDoc != null) 'document_number': cleanDoc,
        })
        .select(_customerSelectColumns)
        .single()
        .timeout(_timeout);

    final customerId = res['id'] as String;

    try {
      await _supabase
          .from('customer_credits')
          .insert({
            'customer_record_id': customerId,
            'credit_limit': 0.0,
            'current_debt': 0.0,
            'is_active': true,
          })
          .timeout(_timeout);
    } catch (creditErr, st) {
      LoggerService.w(
        'No se pudo inicializar customer_credits en createCustomer fallback',
        tag: _tag,
        error: creditErr,
        stackTrace: st,
      );
    }

    return _mapCustomerRow(res, overrideDebt: 0.0, overrideCreditLimit: 0.0);
  }

  @override
  Future<CustomerEntity> updateCustomer({
    required String customerId,
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
    bool? isActive,
  }) async {
    final data = <String, dynamic>{
      'full_name': fullName.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (phone != null) {
      data['phone'] = phone.trim().isEmpty ? null : phone.trim();
    }
    if (documentNumber != null) {
      data['document_number'] =
          documentNumber.trim().isEmpty ? null : documentNumber.trim();
    }
    if (documentType != null) {
      data['document_type'] = documentType;
      data['customer_type'] = documentType == 'RUC' ? 'COMPANY' : 'PERSON';
    }
    if (isActive != null) {
      data['is_active'] = isActive;
    }

    final res = await _supabase
        .from('customers')
        .update(data)
        .eq('id', customerId)
        .select(_customerSelectColumns)
        .single()
        .timeout(_timeout);

    return _mapCustomerRow(res);
  }

  @override
  Future<void> saveCustomerFullProfile({
    String? customerId,
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
    required bool isActive,
    required int walletAdjustDelta,
    required double currentWalletBalance,
    required bool hasCredit,
    required bool creditExistsInDb,
    String? creditId,
    required bool creditIsActive,
    required double newCreditLimit,
  }) async {
    final cleanName = fullName.trim();
    final cleanPhone =
        (phone != null && phone.trim().isNotEmpty) ? phone.trim() : null;
    final cleanDoc =
        (documentNumber != null && documentNumber.trim().isNotEmpty)
            ? documentNumber.trim()
            : null;
    final cleanDocType = documentType ?? 'DNI';

    try {
      await _supabase
          .rpc(
            'save_customer_full_profile_rpc',
            params: {
              'p_customer_id': customerId,
              'p_full_name': cleanName,
              'p_phone': cleanPhone,
              'p_document_number': cleanDoc,
              'p_document_type': cleanDocType,
              'p_is_active': isActive,
              'p_wallet_delta': walletAdjustDelta,
              'p_has_credit': hasCredit,
              'p_credit_limit': newCreditLimit,
            },
          )
          .timeout(_timeout);
      return;
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'save_customer_full_profile_rpc no disponible; usando fallback sobre customers.',
        tag: _tag,
      );
    }

    String? adminProfileId;
    final authUserId = _supabase.auth.currentUser?.id;
    if (authUserId != null) {
      final adminResp = await _supabase
          .from('profiles')
          .select('id')
          .or('auth_user_id.eq.$authUserId,id.eq.$authUserId')
          .maybeSingle()
          .timeout(_timeout);
      if (adminResp != null) adminProfileId = adminResp['id'] as String?;
    }

    final custType = cleanDocType == 'RUC' ? 'COMPANY' : 'PERSON';
    const validDocTypes = {'DNI', 'RUC', 'CE', 'PASAPORTE'};
    final normDocType =
        validDocTypes.contains(cleanDocType) ? cleanDocType : 'OTRO';

    final customerData = <String, dynamic>{
      'customer_type': custType,
      'full_name': cleanName,
      'phone': cleanPhone,
      'document_type': normDocType,
      'document_number': cleanDoc,
      'is_active': isActive,
      'updated_by': adminProfileId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    String finalCustomerId;
    if (customerId != null) {
      final nextWallet =
          (currentWalletBalance + walletAdjustDelta).clamp(0, 99999999).toInt();
      if (walletAdjustDelta != 0) {
        customerData['wallet_balance'] = nextWallet;
      }

      await _supabase
          .from('customers')
          .update(customerData)
          .eq('id', customerId)
          .timeout(_timeout);
      finalCustomerId = customerId;

      if (walletAdjustDelta != 0) {
        await _supabase
            .from('wallet_movements')
            .insert({
              'customer_id': finalCustomerId,
              'points': walletAdjustDelta,
              'movement_type': 'ADJUSTMENT',
              'description':
                  walletAdjustDelta > 0
                      ? 'Ajuste manual (+$walletAdjustDelta monedas)'
                      : 'Ajuste manual ($walletAdjustDelta monedas)',
            })
            .timeout(_timeout);
      }
    } else {
      final initialWallet = walletAdjustDelta > 0 ? walletAdjustDelta : 0;
      final inserted = await _supabase
          .from('customers')
          .insert({
            ...customerData,
            'wallet_balance': initialWallet,
            'created_by': adminProfileId,
          })
          .select('id')
          .single()
          .timeout(_timeout);
      finalCustomerId = inserted['id'] as String;

      if (initialWallet > 0) {
        await _supabase
            .from('wallet_movements')
            .insert({
              'customer_id': finalCustomerId,
              'points': initialWallet,
              'movement_type': 'ADJUSTMENT',
              'description': 'Ajuste manual (+$initialWallet monedas)',
            })
            .timeout(_timeout);
      }
    }

    if (hasCredit) {
      final existingCredit =
          creditExistsInDb ||
          (await _supabase
                  .from('customer_credits')
                  .select('id')
                  .eq('customer_record_id', finalCustomerId)
                  .maybeSingle()
                  .timeout(_timeout)) !=
              null;

      if (existingCredit) {
        final updateQuery = _supabase.from('customer_credits').update({
          'credit_limit': newCreditLimit,
          'is_active': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        if (creditId != null) {
          await updateQuery.eq('id', creditId).timeout(_timeout);
        } else {
          await updateQuery
              .eq('customer_record_id', finalCustomerId)
              .timeout(_timeout);
        }
      } else {
        await _supabase
            .from('customer_credits')
            .insert({
              'customer_record_id': finalCustomerId,
              'credit_limit': newCreditLimit,
              'current_debt': 0.0,
              'is_active': true,
              'created_by': adminProfileId,
            })
            .timeout(_timeout);
      }
    } else if (creditExistsInDb && creditId != null && creditIsActive) {
      await _supabase
          .from('customer_credits')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', creditId)
          .timeout(_timeout);
    }
  }

  @override
  Future<void> toggleCustomerStatus(String customerId, bool isActive) async {
    try {
      await _supabase
          .rpc(
            'toggle_customer_status_rpc',
            params: {'p_customer_id': customerId, 'p_is_active': isActive},
          )
          .timeout(_timeout);
      return;
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'toggle_customer_status_rpc no disponible; usando fallback sobre customers.',
        tag: _tag,
      );
    }

    await _supabase
        .from('customers')
        .update({
          'is_active': isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', customerId)
        .timeout(_timeout);
  }

  @override
  Future<CustomersGlobalStatsEntity> getGlobalStats() async {
    try {
      final dynamic res = await _supabase
          .rpc('get_customers_global_stats_rpc')
          .timeout(_timeout);
      if (res is Map<String, dynamic>) {
        final totalCustomers =
            (res['totalCustomersCount'] ??
                    res['total_customers_count'] ??
                    res['total_count'] ??
                    res['totalCount'] as num?)
                ?.toInt() ??
            0;
        final activeCustomers =
            (res['activeCustomersCount'] ??
                    res['active_customers_count'] ??
                    res['active_count'] ??
                    res['activeCount'] as num?)
                ?.toInt() ??
            0;
        final inactiveCustomers =
            (res['inactiveCustomersCount'] ??
                    res['inactive_customers_count'] ??
                    res['inactive_count'] ??
                    res['inactiveCount'] as num?)
                ?.toInt() ??
            0;
        final totalRevenue =
            (res['totalRevenue'] ?? res['total_revenue'] as num?)?.toDouble() ??
            0.0;
        final totalDebt =
            (res['totalDebt'] ?? res['total_debt'] as num?)?.toDouble() ?? 0.0;
        final debtCustomers =
            (res['debtCustomersCount'] ?? res['debt_customers_count'] as num?)
                ?.toInt() ??
            0;
        final totalWallet =
            (res['totalWalletBalance'] ?? res['total_wallet_balance'] as num?)
                ?.toDouble() ??
            0.0;

        return CustomersGlobalStatsEntity(
          totalCustomersCount: totalCustomers,
          activeCustomersCount: activeCustomers,
          inactiveCustomersCount: inactiveCustomers,
          totalRevenue: totalRevenue,
          totalDebt: totalDebt,
          debtCustomersCount: debtCustomers,
          totalWalletBalance: totalWallet,
        );
      }
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'get_customers_global_stats_rpc no disponible; usando fallback cliente.',
        tag: _tag,
      );
    }

    final customersRes = await _supabase
        .from('customers')
        .select('is_active, wallet_balance')
        .timeout(_timeout);

    int activeCount = 0;
    int inactiveCount = 0;
    double totalWallet = 0.0;
    for (final p in customersRes) {
      if (p['is_active'] == true) {
        activeCount++;
      } else {
        inactiveCount++;
      }
      totalWallet += (p['wallet_balance'] as num?)?.toDouble() ?? 0.0;
    }

    final ordersRes = await _supabase
        .from('orders')
        .select('total_amount')
        .eq('status', 'COMPLETED')
        .limit(500)
        .timeout(_timeout);

    double totalRevenue = 0.0;
    for (final row in ordersRes) {
      totalRevenue += (row['total_amount'] as num?)?.toDouble() ?? 0.0;
    }

    final creditsRes = await _supabase
        .from('customer_credits')
        .select('current_debt')
        .gt('current_debt', 0)
        .timeout(_timeout);
    double totalDebt = 0.0;
    int debtCustomersCount = 0;
    for (final row in creditsRes) {
      final debt = (row['current_debt'] as num?)?.toDouble() ?? 0.0;
      totalDebt += debt;
      if (debt > 0) debtCustomersCount++;
    }

    return CustomersGlobalStatsEntity(
      totalCustomersCount: customersRes.length,
      activeCustomersCount: activeCount,
      inactiveCustomersCount: inactiveCount,
      totalRevenue: totalRevenue,
      totalDebt: totalDebt,
      debtCustomersCount: debtCustomersCount,
      totalWalletBalance: totalWallet,
    );
  }

  @override
  Future<List<CustomerEntity>> getTopCustomers(
    int limit, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final dynamic res = await _supabase
          .rpc(
            'get_top_customers_rpc',
            params: {
              'p_limit': limit,
              'p_start_date': startDate?.toUtc().toIso8601String(),
              'p_end_date': endDate?.toUtc().toIso8601String(),
            },
          )
          .timeout(_timeout);

      if (res is List) {
        return res
            .map((row) => _mapCustomerRow(row as Map<String, dynamic>))
            .toList(growable: false);
      }
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      // Intentar firma heredada de 1 parámetro cuando no hay filtro de fechas
      if (startDate == null && endDate == null) {
        try {
          final dynamic legacyRes = await _supabase
              .rpc('get_top_customers_rpc', params: {'p_limit': limit})
              .timeout(_timeout);
          if (legacyRes is List) {
            return legacyRes
                .map((row) => _mapCustomerRow(row as Map<String, dynamic>))
                .toList(growable: false);
          }
        } on PostgrestException catch (legacyErr) {
          if (!_isMissingRpc(legacyErr)) rethrow;
        }
      }
      LoggerService.w(
        'get_top_customers_rpc no disponible; usando fallback PostgREST.',
        tag: _tag,
      );
    }

    var ordersQuery = _supabase
        .from('orders')
        .select('customer_record_id, total_amount, created_at')
        .eq('status', 'COMPLETED')
        .not('customer_record_id', 'is', null);

    if (startDate != null) {
      ordersQuery = ordersQuery.gte(
        'created_at',
        startDate.toUtc().toIso8601String(),
      );
    }
    if (endDate != null) {
      ordersQuery = ordersQuery.lte(
        'created_at',
        endDate.toUtc().toIso8601String(),
      );
    }

    final ordersRes = await ordersQuery.limit(1000).timeout(_timeout);

    final revMap = <String, double>{};
    final countMap = <String, int>{};
    final lastOrderMap = <String, DateTime>{};
    for (final row in ordersRes) {
      final cid = row['customer_record_id'] as String?;
      if (cid != null && cid.trim().isNotEmpty) {
        revMap[cid] =
            (revMap[cid] ?? 0.0) +
            ((row['total_amount'] as num?)?.toDouble() ?? 0.0);
        countMap[cid] = (countMap[cid] ?? 0) + 1;
        final dt =
            row['created_at'] != null
                ? DateTime.tryParse(row['created_at'].toString())
                : null;
        if (dt != null &&
            (lastOrderMap[cid] == null || dt.isAfter(lastOrderMap[cid]!))) {
          lastOrderMap[cid] = dt;
        }
      }
    }

    final sortedEntries =
        revMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topIds =
        sortedEntries.take(limit).map((e) => e.key).toList(growable: false);

    if (topIds.isEmpty) return const [];

    final topCustomersRes = await _supabase
        .from('customers')
        .select(_customerSelectColumns)
        .inFilter('id', topIds)
        .timeout(_timeout);

    final list = topCustomersRes.map<CustomerEntity>((json) {
      final cid = json['id'] as String;
      return _mapCustomerRow(
        json,
        overrideRevenue: revMap[cid] ?? 0.0,
        overrideOrderCount: countMap[cid] ?? 0,
        overrideLastOrderAt: lastOrderMap[cid],
      );
    }).toList();

    list.sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    return list;
  }

  @override
  Future<List<RecentOrderEntity>> getCustomerRecentOrders(
    String customerId,
  ) async {
    final res = await _supabase
        .from('orders')
        .select(
          'id, created_at, total_amount, amount_paid, discount_amount, status, payment_status, payment_method, points_earned, points_used, due_date',
        )
        .or('customer_record_id.eq.$customerId,customer_id.eq.$customerId')
        .order('created_at', ascending: false)
        .limit(10)
        .timeout(_timeout);

    return res
        .map<RecentOrderEntity>((json) {
          return RecentOrderEntity(
            id: json['id'] as String,
            createdAt: DateTime.parse(json['created_at']),
            totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
            amountPaid: (json['amount_paid'] as num?)?.toDouble() ?? 0.0,
            discountAmount:
                (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
            status: json['status'] as String? ?? 'COMPLETED',
            paymentStatus: json['payment_status'] as String? ?? 'PAID',
            paymentMethod: json['payment_method'] as String? ?? 'EFECTIVO',
            pointsEarned: (json['points_earned'] as num?)?.toInt() ?? 0,
            pointsUsed: (json['points_used'] as num?)?.toInt() ?? 0,
            dueDate:
                json['due_date'] != null
                    ? DateTime.tryParse(json['due_date'])
                    : null,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<TopProductEntity>> getCustomerTopProducts(
    String customerId,
  ) async {
    final completedOrders = await _supabase
        .from('orders')
        .select('id')
        .or('customer_record_id.eq.$customerId,customer_id.eq.$customerId')
        .eq('status', 'COMPLETED')
        .order('created_at', ascending: false)
        .limit(50)
        .timeout(_timeout);

    final orderIds = completedOrders
        .map((row) => row['id'] as String)
        .toList(growable: false);
    if (orderIds.isEmpty) return const [];

    final res = await _supabase
        .from('order_items')
        .select('''
          quantity, applied_price,
          products(id, name, product_images(image_url, is_main)),
          product_variants(id, product_images(image_url, is_main))
        ''')
        .inFilter('order_id', orderIds)
        .limit(200)
        .timeout(_timeout);

    final productMap =
        <String, ({int qty, double spent, String? imageUrl})>{};
    for (final row in res) {
      final productsObj = row['products'] as Map<String, dynamic>?;
      final pname = productsObj?['name'] as String? ?? 'Producto';
      final qty = (row['quantity'] as num?)?.toInt() ?? 0;
      final price = (row['applied_price'] as num?)?.toDouble() ?? 0.0;

      String? imageUrl;
      if (productsObj != null) {
        final prodImgs = productsObj['product_images'] as List<dynamic>? ?? [];
        if (prodImgs.isNotEmpty) {
          final mainImg =
              prodImgs.firstWhere(
                    (img) => (img as Map<String, dynamic>)['is_main'] == true,
                    orElse: () => prodImgs.first,
                  )
                  as Map<String, dynamic>?;
          imageUrl = mainImg?['image_url'] as String?;
        }
      }

      if (imageUrl == null && row['product_variants'] is Map) {
        final varMap = row['product_variants'] as Map<String, dynamic>;
        final varImgs = varMap['product_images'] as List<dynamic>? ?? [];
        if (varImgs.isNotEmpty) {
          final mainImg =
              varImgs.firstWhere(
                    (img) => (img as Map<String, dynamic>)['is_main'] == true,
                    orElse: () => varImgs.first,
                  )
                  as Map<String, dynamic>?;
          imageUrl = mainImg?['image_url'] as String?;
        }
      }

      final current = productMap[pname] ?? (qty: 0, spent: 0.0, imageUrl: null);
      productMap[pname] = (
        qty: current.qty + qty,
        spent: current.spent + (qty * price),
        imageUrl: current.imageUrl ?? imageUrl,
      );
    }

    final sorted =
        productMap.entries.toList()
          ..sort((a, b) => b.value.spent.compareTo(a.value.spent));

    return sorted
        .take(5)
        .map((e) {
          return TopProductEntity(
            productName: e.key,
            totalQuantity: e.value.qty,
            totalSpent: e.value.spent,
            imageUrl: e.value.imageUrl,
          );
        })
        .toList(growable: false);
  }
}
