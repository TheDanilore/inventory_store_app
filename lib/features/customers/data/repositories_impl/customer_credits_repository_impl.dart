import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/app_exception.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
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
    try {
      final cleanQuery = query?.trim() ?? '';

      // 1. Estadísticas Globales mediante RPC (Cero Data Egress) con Fallback defensivo
      double totalDebt = 0;
      int activeAccounts = 0;
      int suspendedAccounts = 0;
      int maxedOutAccounts = 0;

      try {
        final statsResult = await _supabase.rpc(
          'get_customer_credits_stats_rpc',
          params: {'p_search_query': cleanQuery},
        );
        if (statsResult is Map) {
          totalDebt = (statsResult['totalDebt'] as num?)?.toDouble() ?? 0.0;
          activeAccounts = (statsResult['activeAccounts'] as num?)?.toInt() ?? 0;
          suspendedAccounts = (statsResult['suspendedAccounts'] as num?)?.toInt() ?? 0;
          maxedOutAccounts = (statsResult['maxedOutAccounts'] as num?)?.toInt() ?? 0;
        }
      } catch (statsErr) {
        LoggerService.w(
          'get_customer_credits_stats_rpc no disponible o falló, usando fallback: $statsErr',
          tag: 'CUSTOMER_CREDITS_REPO',
        );
        final statsResponse = await _supabase
            .from('customer_credits')
            .select('current_debt, is_active, credit_limit');
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
      }

      // 2. Consulta unificada paginada con conteo exacto nativo de PostgREST
      const selectFields = '''
        id,
        profile_id,
        credit_limit,
        current_debt,
        is_active,
        created_at,
        updated_at,
        profiles!customer_credits_profile_id_fkey!inner ( id, full_name, phone, document_number, document_type )
      ''';

      var queryBuilder = _supabase.from('customer_credits').select(selectFields);

      if (cleanQuery.isNotEmpty) {
        queryBuilder = queryBuilder.or(
          'profiles.full_name.ilike.%$cleanQuery%,profiles.document_number.ilike.%$cleanQuery%,profiles.phone.ilike.%$cleanQuery%',
        );
      }

      if (showOnlyWithDebt) {
        queryBuilder = queryBuilder.gt('current_debt', 0);
      }

      final response = await queryBuilder
          .order('current_debt', ascending: false)
          .range(offset, offset + limit - 1)
          .count(CountOption.exact);

      final totalCount = response.count;
      final accounts = (response.data as List)
          .map((e) => CreditAccountModel.fromJoin(e).toEntity())
          .toList();

      return CustomerCreditListResultEntity(
        accounts: accounts,
        totalCount: totalCount,
        totalDebt: totalDebt,
        activeAccounts: activeAccounts,
        suspendedAccounts: suspendedAccounts,
        maxedOutAccounts: maxedOutAccounts,
      );
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'PostgrestException en getCreditAccounts: ${e.message}',
        tag: 'CUSTOMER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      throw ServerException(message: 'Error en base de datos: ${e.message}');
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en getCreditAccounts',
        tag: 'CUSTOMER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      throw ServerException(message: 'Error al consultar créditos: $e');
    }
  }

  @override
  Future<CustomerCreditEntity?> getCreditAccountByCustomer(
    String customerId,
  ) async {
    try {
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
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'PostgrestException en getCreditAccountByCustomer: ${e.message}',
        tag: 'CUSTOMER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      throw ServerException(message: 'Error al obtener cuenta: ${e.message}');
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en getCreditAccountByCustomer',
        tag: 'CUSTOMER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      throw ServerException(message: 'Error al obtener cuenta: $e');
    }
  }

  @override
  Future<CustomerCreditEntity> createCreditAccount({
    required String customerId,
    required double creditLimit,
  }) async {
    try {
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
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'PostgrestException en createCreditAccount: ${e.message}',
        tag: 'CUSTOMER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      throw ServerException(message: 'Error al crear cuenta: ${e.message}');
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en createCreditAccount',
        tag: 'CUSTOMER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      throw ServerException(message: 'Error al crear cuenta de crédito: $e');
    }
  }

  @override
  Future<CustomerCreditEntity> updateCreditLimit({
    required String creditId,
    required double newLimit,
  }) async {
    try {
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
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'PostgrestException en updateCreditLimit: ${e.message}',
        tag: 'CUSTOMER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      throw ServerException(message: 'Error al actualizar límite: ${e.message}');
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en updateCreditLimit',
        tag: 'CUSTOMER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      throw ServerException(message: 'Error al actualizar límite: $e');
    }
  }

  @override
  Future<void> toggleCreditStatus(String creditId, bool isActive) async {
    try {
      await _supabase
          .from('customer_credits')
          .update({'is_active': isActive})
          .eq('id', creditId);
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'PostgrestException en toggleCreditStatus: ${e.message}',
        tag: 'CUSTOMER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      throw ServerException(message: 'Error al cambiar estado: ${e.message}');
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en toggleCreditStatus',
        tag: 'CUSTOMER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      throw ServerException(message: 'Error al cambiar estado de crédito: $e');
    }
  }

  @override
  Future<({List<CreditMovementEntity> items, int totalCount})> getCreditMovements({
    required String creditId,
    required int limit,
    required int offset,
    String? dateFilter,
    String? movementType,
  }) async {
    // 1. Intentar consultar vista con nombres y pedidos pre-unidos
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
          final date = now.subtract(const Duration(days: 30)).toIso8601String();
          query = query.gte('created_at', date);
        } else if (dateFilter == 'this_month') {
          final date = DateTime(now.year, now.month, 1).toIso8601String();
          query = query.gte('created_at', date);
        }
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1)
          .count(CountOption.exact);

      final totalCount = response.count;
      final items = (response.data as List)
          .map(
            (e) =>
                CustomerCreditMovementModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ).toEntity(),
          )
          .toList();

      return (items: items, totalCount: totalCount);
    } catch (viewErr) {
      LoggerService.w(
        'customer_credit_movements_summary falló, intentando con joins en tabla: $viewErr',
        tag: 'CUSTOMER_CREDITS_REPO',
      );

      // 2. Fallback resiliente directo a tabla con select explícito
      try {
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
            final date = now.subtract(const Duration(days: 30)).toIso8601String();
            fbQuery = fbQuery.gte('created_at', date);
          } else if (dateFilter == 'this_month') {
            final date = DateTime(now.year, now.month, 1).toIso8601String();
            fbQuery = fbQuery.gte('created_at', date);
          }
        }

        final fbResponse = await fbQuery
            .order('created_at', ascending: false)
            .range(offset, offset + limit - 1)
            .count(CountOption.exact);

        final totalCount = fbResponse.count;
        final items = (fbResponse.data as List)
            .map(
              (e) =>
                  CustomerCreditMovementModel.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ).toEntity(),
            )
            .toList();

        return (items: items, totalCount: totalCount);
      } on PostgrestException catch (e, st) {
        LoggerService.e(
          'PostgrestException en getCreditMovements: ${e.message}',
          tag: 'CUSTOMER_CREDITS_REPO',
          error: e,
          stackTrace: st,
        );
        throw ServerException(
          message: 'Error al obtener movimientos: ${e.message}',
        );
      } catch (e, st) {
        LoggerService.e(
          'Error inesperado en getCreditMovements',
          tag: 'CUSTOMER_CREDITS_REPO',
          error: e,
          stackTrace: st,
        );
        throw ServerException(message: 'Error al obtener movimientos: $e');
      }
    }
  }

  @override
  Future<({double totalCharged, double totalPaid, int chargeCount, int paymentCount})> getCreditMovementsTotals({
    required String creditId,
    String? dateFilter,
  }) async {
    try {
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
      int chargeCount = 0;
      int paymentCount = 0;
      for (var row in (response as List)) {
        final amount = (row['amount'] as num).toDouble();
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
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'PostgrestException en getCreditMovementsTotals: ${e.message}',
        tag: 'CUSTOMER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      return (totalCharged: 0.0, totalPaid: 0.0, chargeCount: 0, paymentCount: 0);
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en getCreditMovementsTotals',
        tag: 'CUSTOMER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      return (totalCharged: 0.0, totalPaid: 0.0, chargeCount: 0, paymentCount: 0);
    }
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
  }) async {
    try {
      final response = await _supabase.rpc(
        'register_credit_payment_rpc',
        params: {
          'p_customer_id': customerId,
          'p_credit_id': creditId.isNotEmpty ? creditId : null,
          'p_amount': amount,
          'p_account_id': accountId,
          'p_order_id': orderId,
          'p_notes': notes,
          'p_shift_id': shiftId,
        },
      );

      final result = response as Map<String, dynamic>?;
      final didSucceed = result?['success'] == true;
      if (!didSucceed) {
        final errMsg =
            result?['error'] as String? ??
            result?['detail'] as String? ??
            'Error desconocido del servidor al registrar abono.';
        throw ServerException(message: errMsg);
      }
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'PostgrestException en register_credit_payment_rpc: ${e.message}',
        tag: 'CUSTOMER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      throw ServerException(message: 'Error de base de datos: ${e.message}');
    } catch (e, st) {
      if (e is ServerException) rethrow;
      LoggerService.e(
        'Error inesperado en register_credit_payment_rpc',
        tag: 'CUSTOMER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      throw ServerException(message: 'Error inesperado: $e');
    }
  }
}
