import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/purchases/data/models/supplier_credit_models.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';

abstract class SupplierCreditsRemoteDataSource {
  Future<SupplierCreditsPageEntity> fetchAccountsPage({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool withDebtOnly = false,
    bool includeStats = true,
  });

  Future<SupplierCreditEntity?> toggleAccountStatus(
    String creditId,
    bool currentStatus,
  );

  Future<SupplierCreditEntity?> saveAccount({
    required String? creditId,
    required String supplierId,
    required double creditLimit,
  });

  Future<SupplierCreditEntity?> registerPayment({
    required String supplierId,
    required String creditId,
    required double amount,
    required String? accountId,
    required String? orderId,
    required String notes,
    required String? shiftId,
    required String? adminProfileId,
    String? idempotencyKey,
  });

  Future<List<SupplierCandidateEntity>> searchAvailableSuppliers(String query);

  Future<List<PendingPurchaseOrderEntity>> getPendingPurchaseOrders(
    String supplierId,
  );

  Future<List<SupplierFinancialAccountOption>> getFinancialAccounts();

  Future<ActiveCashShiftEntity?> getActiveCashShift(String accountId);

  // Métodos legados mantenidos para compatibilidad con otros flujos
  Future<List<Map<String, dynamic>>> searchSuppliersLegacy(
    String query,
    Set<String> existingSupplierIds,
  );
  Future<Set<String>> getExistingCreditSupplierIds({
    String? excludeSupplierId,
  });
  Future<List<Map<String, dynamic>>> getPendingPurchaseOrdersRaw(
    String supplierId,
  );
  Future<Map<String, dynamic>?> getActiveCashShiftRaw(String accountId);
  Future<String?> getAdminProfileId();
}

@LazySingleton(as: SupplierCreditsRemoteDataSource)
class SupplierCreditsRemoteDataSourceImpl
    implements SupplierCreditsRemoteDataSource {
  final SupabaseClient _supabase;
  static const Duration _timeout = Duration(seconds: 15);
  static const String _tag = 'SUPPLIER_CREDITS_DS';

  SupplierCreditsRemoteDataSourceImpl(this._supabase);

  bool _isMissingRpc(PostgrestException e) {
    return e.code == 'PGRST202' ||
        e.code == '42883' ||
        e.message.contains('Could not find the function');
  }

  /// Sanitiza entrada para filtros `.or()` de PostgREST (previene rupturas con `,`, `(`, `)`).
  String _sanitizePostgrestToken(String input) {
    return input.trim().replaceAll(RegExp(r'[,()]'), ' ');
  }

  @override
  Future<SupplierCreditsPageEntity> fetchAccountsPage({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool withDebtOnly = false,
    bool includeStats = true,
  }) async {
    final trimmed = searchQuery.trim();
    final offset = page * pageSize;

    try {
      final dynamic rpcRes = await _supabase
          .rpc(
            'get_supplier_credits_page_rpc',
            params: {
              'p_search_query': trimmed,
              'p_with_debt_only': withDebtOnly,
              'p_limit': pageSize,
              'p_offset': offset,
              'p_include_stats': includeStats,
            },
          )
          .timeout(_timeout);

      final map = rpcRes as Map<String, dynamic>? ?? const {};
      final rawItems = (map['items'] as List<dynamic>?) ?? const [];
      final accounts =
          rawItems
              .map(
                (item) => SupplierCreditModel.fromView(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(growable: false);

      final rawStats = map['stats'] as Map<String, dynamic>?;
      final stats =
          rawStats != null ? SupplierCreditStatsModel.fromJson(rawStats) : null;
      final totalCount = (map['totalCount'] as num?)?.toInt() ?? 0;

      return SupplierCreditsPageEntity(
        accounts: accounts,
        totalCount: totalCount,
        stats: stats,
      );
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'get_supplier_credits_page_rpc no disponible aún; usando fallback paralelo.',
        tag: _tag,
      );
      return _fetchAccountsPageFallback(
        page: page,
        pageSize: pageSize,
        searchQuery: trimmed,
        withDebtOnly: withDebtOnly,
        includeStats: includeStats,
      );
    }
  }

  Future<SupplierCreditsPageEntity> _fetchAccountsPageFallback({
    required int page,
    required int pageSize,
    required String searchQuery,
    required bool withDebtOnly,
    required bool includeStats,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;
    final sanitized = _sanitizePostgrestToken(searchQuery);

    var query = _supabase
        .from('supplier_credits')
        .select(
          'id, supplier_id, credit_limit, current_debt, is_active, suppliers!inner(name, tax_id, phone)',
        );

    if (sanitized.isNotEmpty) {
      query = query.or(
        'suppliers.name.ilike.%$sanitized%,suppliers.tax_id.ilike.%$sanitized%,suppliers.phone.ilike.%$sanitized%',
      );
    }
    if (withDebtOnly) {
      query = query.gt('current_debt', 0).eq('is_active', true);
    }

    final Future<dynamic>? statsFuture =
        includeStats
            ? _supabase
                .rpc(
                  'get_supplier_credits_stats_rpc',
                  params: {'p_search_query': searchQuery},
                )
                .timeout(_timeout)
            : null;

    final Future<PostgrestResponse<List<Map<String, dynamic>>>> listFuture =
        query
            .order('current_debt', ascending: false)
            .range(from, to)
            .count(CountOption.exact)
            .timeout(_timeout);

    final results = await Future.wait([
      listFuture,
      if (statsFuture != null) statsFuture,
    ]);

    final response =
        results[0] as PostgrestResponse<List<Map<String, dynamic>>>;
    final accounts =
        response.data
            .map(SupplierCreditModel.fromView)
            .toList(growable: false);

    SupplierCreditStatsEntity? stats;
    if (statsFuture != null) {
      final statsMap = results[1] as Map<String, dynamic>? ?? const {};
      stats = SupplierCreditStatsModel.fromJson(statsMap);
    }

    return SupplierCreditsPageEntity(
      accounts: accounts,
      totalCount: response.count,
      stats: stats,
    );
  }

  @override
  Future<SupplierCreditEntity?> toggleAccountStatus(
    String creditId,
    bool currentStatus,
  ) async {
    final nextStatus = !currentStatus;
    try {
      final dynamic rpcRes = await _supabase
          .rpc(
            'rpc_toggle_supplier_credit_status',
            params: {'p_credit_id': creditId, 'p_is_active': nextStatus},
          )
          .timeout(_timeout);

      final res = rpcRes as Map<String, dynamic>?;
      if (res?['success'] != true) {
        throw PostgrestException(
          message:
              res?['error']?.toString() ?? 'Error al cambiar estado del crédito.',
          code: res?['detail']?.toString() ?? 'P0001',
        );
      }

      final creditJson = res?['credit'] as Map<String, dynamic>?;
      return creditJson != null ? SupplierCreditModel.fromView(creditJson) : null;
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'rpc_toggle_supplier_credit_status no disponible; usando fallback update.',
        tag: _tag,
      );
      await _supabase
          .from('supplier_credits')
          .update({
            'is_active': nextStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', creditId)
          .timeout(_timeout);
      return null;
    }
  }

  @override
  Future<SupplierCreditEntity?> saveAccount({
    required String? creditId,
    required String supplierId,
    required double creditLimit,
  }) async {
    if (creditId != null) {
      try {
        final dynamic rpcRes = await _supabase
            .rpc(
              'rpc_update_supplier_credit_limit',
              params: {'p_credit_id': creditId, 'p_credit_limit': creditLimit},
            )
            .timeout(_timeout);

        final res = rpcRes as Map<String, dynamic>?;
        if (res?['success'] != true) {
          throw PostgrestException(
            message:
                res?['error']?.toString() ??
                'Error al actualizar límite de crédito.',
            code: res?['detail']?.toString() ?? 'P0001',
          );
        }

        final creditJson = res?['credit'] as Map<String, dynamic>?;
        return creditJson != null
            ? SupplierCreditModel.fromView(creditJson)
            : null;
      } on PostgrestException catch (e) {
        if (!_isMissingRpc(e)) rethrow;
        LoggerService.w(
          'rpc_update_supplier_credit_limit no disponible; usando fallback update.',
          tag: _tag,
        );
        await _supabase
            .from('supplier_credits')
            .update({
              'credit_limit': creditLimit,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', creditId)
            .timeout(_timeout);
        return null;
      }
    }

    final dynamic response = await _supabase
        .rpc(
          'rpc_create_supplier_credit',
          params: {'p_supplier_id': supplierId, 'p_credit_limit': creditLimit},
        )
        .timeout(_timeout);

    final res = response as Map<String, dynamic>?;
    if (res?['success'] != true) {
      throw PostgrestException(
        message: res?['error']?.toString() ?? 'Error al crear crédito.',
        code: res?['detail']?.toString() ?? 'P0001',
      );
    }
    return null;
  }

  @override
  Future<SupplierCreditEntity?> registerPayment({
    required String supplierId,
    required String creditId,
    required double amount,
    required String? accountId,
    required String? orderId,
    required String notes,
    required String? shiftId,
    required String? adminProfileId,
    String? idempotencyKey,
  }) async {
    final baseParams = <String, dynamic>{
      'p_supplier_id': supplierId,
      'p_credit_id': creditId.isNotEmpty ? creditId : null,
      'p_amount': amount,
      'p_account_id': accountId,
      'p_order_id': orderId,
      'p_notes': notes,
      'p_shift_id': shiftId,
      'p_profile_id': adminProfileId ?? _supabase.auth.currentUser?.id,
    };

    dynamic response;
    try {
      response = await _supabase
          .rpc(
            'register_supplier_credit_payment_rpc',
            params: {
              ...baseParams,
              if (idempotencyKey != null) 'p_idempotency_key': idempotencyKey,
            },
          )
          .timeout(_timeout);
    } on PostgrestException catch (e) {
      if (idempotencyKey == null || !_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'register_supplier_credit_payment_rpc sin p_idempotency_key; reintentando firma previa.',
        tag: _tag,
      );
      response = await _supabase
          .rpc('register_supplier_credit_payment_rpc', params: baseParams)
          .timeout(_timeout);
    }

    final result = response as Map<String, dynamic>?;
    if (result?['success'] != true) {
      throw PostgrestException(
        message:
            result?['error'] as String? ??
            result?['detail'] as String? ??
            'Error desconocido en el servidor.',
        code: result?['detail']?.toString() ?? 'P0001',
      );
    }

    final updatedJson = result?['updated_credit'] as Map<String, dynamic>?;
    return updatedJson != null
        ? SupplierCreditModel.fromView(updatedJson)
        : null;
  }

  @override
  Future<List<SupplierCandidateEntity>> searchAvailableSuppliers(
    String query,
  ) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    try {
      final dynamic rpcRes = await _supabase
          .rpc(
            'search_suppliers_without_credit_rpc',
            params: {'p_query': trimmed, 'p_limit': 6},
          )
          .timeout(_timeout);

      return (rpcRes as List<dynamic>)
          .map(
            (e) =>
                SupplierCandidateModel.fromJson(e as Map<String, dynamic>),
          )
          .toList(growable: false);
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e)) rethrow;
      LoggerService.w(
        'search_suppliers_without_credit_rpc no disponible; usando fallback legado.',
        tag: _tag,
      );
      final existingIds = await getExistingCreditSupplierIds();
      final rawList = await searchSuppliersLegacy(trimmed, existingIds);
      return rawList
          .map(SupplierCandidateModel.fromJson)
          .toList(growable: false);
    }
  }

  @override
  Future<List<PendingPurchaseOrderEntity>> getPendingPurchaseOrders(
    String supplierId,
  ) async {
    final list = await getPendingPurchaseOrdersRaw(supplierId);
    return list
        .map(PendingPurchaseOrderModel.fromJson)
        .toList(growable: false);
  }

  @override
  Future<List<SupplierFinancialAccountOption>> getFinancialAccounts() async {
    final resp = await _supabase
        .from('financial_accounts')
        .select('id, name, type, balance')
        .eq('is_active', true)
        .order('name')
        .timeout(_timeout);

    const typeOrder = {'CAJA': 0, 'BANCO': 1, 'DIGITAL': 2, 'OTRO': 3};
    final list =
        (resp as List<dynamic>)
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
    return List.unmodifiable(list);
  }

  @override
  Future<ActiveCashShiftEntity?> getActiveCashShift(String accountId) async {
    final data = await getActiveCashShiftRaw(accountId);
    if (data == null || data.isEmpty) return null;
    return ActiveCashShiftModel.fromJson(data);
  }

  @override
  Future<List<Map<String, dynamic>>> searchSuppliersLegacy(
    String query,
    Set<String> existingSupplierIds,
  ) async {
    final sanitized = _sanitizePostgrestToken(query);
    if (sanitized.isEmpty) return const [];
    final response = await _supabase
        .from('suppliers')
        .select('id, name, tax_id, phone')
        .eq('is_active', true)
        .or(
          'name.ilike.%$sanitized%,tax_id.ilike.%$sanitized%,phone.ilike.%$sanitized%',
        )
        .limit(20)
        .timeout(_timeout);

    return (response as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((p) => !existingSupplierIds.contains(p['id'] as String))
        .take(6)
        .toList(growable: false);
  }

  @override
  Future<Set<String>> getExistingCreditSupplierIds({
    String? excludeSupplierId,
  }) async {
    final existingCredits = await _supabase
        .from('supplier_credits')
        .select('supplier_id')
        .timeout(_timeout);
    return (existingCredits as List<dynamic>)
        .map((e) => e['supplier_id'] as String)
        .where((id) => id != excludeSupplierId)
        .toSet();
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingPurchaseOrdersRaw(
    String supplierId,
  ) async {
    final response = await _supabase
        .from('purchase_orders')
        .select('id, total_amount, amount_paid, payment_status, created_at')
        .eq('supplier_id', supplierId)
        .inFilter('payment_status', ['PENDING', 'PARTIAL'])
        .neq('status', 'CANCELLED')
        .order('created_at', ascending: true)
        .timeout(_timeout);
    return (response as List<dynamic>).cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>?> getActiveCashShiftRaw(String accountId) async {
    return _supabase
        .from('cash_shifts')
        .select('id, opened_at, opening_amount')
        .eq('account_id', accountId)
        .eq('status', 'OPEN')
        .maybeSingle()
        .timeout(_timeout);
  }

  @override
  Future<String?> getAdminProfileId() async {
    final authUserId = _supabase.auth.currentUser?.id;
    if (authUserId == null) return null;
    final resp = await _supabase
        .from('profiles')
        .select('id')
        .eq('auth_user_id', authUserId)
        .maybeSingle()
        .timeout(_timeout);
    return resp?['id'] as String?;
  }
}
