import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credits_repository.dart';
import 'package:inventory_store_app/features/purchases/data/models/supplier_credit_models.dart'
    hide SupplierFinancialAccountOption;

@LazySingleton(as: SupplierCreditsRepository)
class SupplierCreditsRepositoryImpl implements SupplierCreditsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  Future<
    Either<
      Failure,
      ({
        List<SupplierCreditEntity> accounts,
        int count,
        Map<String, dynamic> stats,
      })
    >
  >
  fetchAccountsPaginated({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool withDebtOnly = false,
  }) async {
    try {
      final from = page * pageSize;
      final to = from + pageSize - 1;

      // 1. Obtener estadísticas globales mediante RPC (Cero Data Egress en listas gigantes)
      final statsResult = await _supabase.rpc(
        'get_supplier_credits_stats_rpc',
        params: {'p_search_query': searchQuery},
      );

      final statsMap = statsResult as Map<String, dynamic>? ?? {};
      final totalDebt = (statsMap['totalDebt'] as num?)?.toDouble() ?? 0.0;
      final activeCount = statsMap['activeAccounts'] as int? ?? 0;
      final suspendedCount = statsMap['suspendedAccounts'] as int? ?? 0;
      final maxedOutCount = statsMap['maxedOutAccounts'] as int? ?? 0;
      final debtCount = statsMap['debtCount'] as int? ?? 0;

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

      // ── Optimización de Data Egress: Filtrado nativo en Supabase antes de range ──
      if (withDebtOnly) {
        query = query.gt('current_debt', 0).eq('is_active', true);
      }

      final response = await query
          .order('current_debt', ascending: false)
          .range(from, to)
          .count(CountOption.exact);

      final list =
          (response.data as List).map((item) {
            return SupplierCreditModel.fromView(item);
          }).toList();

      return Right((
        accounts: list,
        count: response.count,
        stats: {
          'totalDebt': totalDebt,
          'activeAccounts': activeCount,
          'suspendedAccounts': suspendedCount,
          'maxedOutAccounts': maxedOutCount,
          'debtCount': debtCount,
        },
      ));
    } catch (e, st) {
      LoggerService.e(
        'Error al obtener cuentas de crédito paginadas',
        tag: 'SUPPLIER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> toggleAccountStatus(
    String creditId,
    bool currentStatus,
  ) async {
    try {
      await _supabase
          .from('supplier_credits')
          .update({
            'is_active': !currentStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', creditId);
      return const Right(null);
    } catch (e, st) {
      LoggerService.e(
        'Error al alternar estado del crédito $creditId',
        tag: 'SUPPLIER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> saveAccount({
    required String? creditId,
    required String supplierId,
    required double creditLimit,
    String? adminProfileId,
  }) async {
    try {
      if (creditId != null) {
        await _supabase
            .from('supplier_credits')
            .update({
              'credit_limit': creditLimit,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', creditId);
      } else {
        // ── Creación Atómica ──────────────────────────────────────────────
        final response = await _supabase.rpc(
          'rpc_create_supplier_credit',
          params: {'p_supplier_id': supplierId, 'p_credit_limit': creditLimit},
        );

        final res = response as Map<String, dynamic>?;
        if (res?['success'] != true) {
          throw Exception(
            res?['error']?.toString() ?? 'Error al crear crédito',
          );
        }
      }
      return const Right(null);
    } catch (e, st) {
      LoggerService.e(
        'Error al guardar cuenta de crédito para proveedor $supplierId',
        tag: 'SUPPLIER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> searchSuppliers(
    String query,
    Set<String> existingSupplierIds,
  ) async {
    try {
      final response = await _supabase
          .from('suppliers')
          .select('id, name, tax_id, phone')
          .eq('is_active', true)
          .or('name.ilike.%$query%,tax_id.ilike.%$query%,phone.ilike.%$query%')
          .limit(20);

      final list =
          (response as List)
              .cast<Map<String, dynamic>>()
              .where((p) => !existingSupplierIds.contains(p['id'] as String))
              .take(6)
              .toList();
      return Right(list);
    } catch (e, st) {
      LoggerService.e(
        'Error buscando proveedores con query: $query',
        tag: 'SUPPLIER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Set<String>>> getExistingCreditSupplierIds({
    String? excludeSupplierId,
  }) async {
    try {
      final existingCredits = await _supabase
          .from('supplier_credits')
          .select('supplier_id');
      final ids =
          (existingCredits as List)
              .map((e) => e['supplier_id'] as String)
              .where((id) => id != excludeSupplierId)
              .toSet();
      return Right(ids);
    } catch (e, st) {
      LoggerService.e(
        'Error obteniendo IDs de proveedores con crédito existente',
        tag: 'SUPPLIER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getPendingPurchaseOrders(
    String supplierId,
  ) async {
    try {
      final list = await _supabase
          .from('purchase_orders')
          .select('id, total_amount, amount_paid, payment_status, created_at')
          .eq('supplier_id', supplierId)
          .inFilter('payment_status', ['PENDING', 'PARTIAL'])
          .order('created_at', ascending: true);
      return Right(list);
    } catch (e, st) {
      LoggerService.e(
        'Error obteniendo órdenes pendientes para el proveedor $supplierId',
        tag: 'SUPPLIER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<SupplierFinancialAccountOption>>>
  getFinancialAccounts() async {
    try {
      final resp = await _supabase
          .from('financial_accounts')
          .select('id, name, type, balance')
          .eq('is_active', true)
          .order('name');

      const typeOrder = {'CAJA': 0, 'BANCO': 1, 'DIGITAL': 2, 'OTRO': 3};
      final list =
          (resp as List)
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
      return Right(list);
    } catch (e, st) {
      LoggerService.e(
        'Error obteniendo cuentas financieras activas',
        tag: 'SUPPLIER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>?>> getActiveCashShift(
    String accountId,
  ) async {
    try {
      final data =
          await _supabase
              .from('cash_shifts')
              .select('id, opened_at, opening_amount')
              .eq('account_id', accountId)
              .eq('status', 'OPEN')
              .maybeSingle();
      return Right(data);
    } catch (e, st) {
      LoggerService.e(
        'Error obteniendo turno activo para la cuenta $accountId',
        tag: 'SUPPLIER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String?>> getAdminProfileId() async {
    try {
      final authUserId = _supabase.auth.currentUser?.id;
      if (authUserId != null) {
        final resp =
            await _supabase
                .from('profiles')
                .select('id')
                .eq('auth_user_id', authUserId)
                .maybeSingle();
        if (resp != null) return Right(resp['id'] as String);
      }
      return const Right(null);
    } catch (e, st) {
      LoggerService.e(
        'Error obteniendo ID de perfil de administrador',
        tag: 'SUPPLIER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> registerPayment({
    required String supplierId,
    required String creditId,
    required double amount,
    required String? accountId,
    required String? orderId,
    required String notes,
    required String? shiftId,
    required String? adminProfileId,
  }) async {
    try {
      final response = await _supabase.rpc(
        'register_supplier_credit_payment_rpc',
        params: {
          'p_supplier_id': supplierId,
          'p_credit_id': creditId.isNotEmpty ? creditId : null,
          'p_amount': amount,
          'p_account_id': accountId,
          'p_order_id': orderId,
          'p_notes': notes,
          'p_shift_id': shiftId,
          'p_profile_id': adminProfileId ?? _supabase.auth.currentUser?.id,
        },
      );

      final result = response as Map<String, dynamic>?;
      final didSucceed = result?['success'] == true;
      if (!didSucceed) {
        final errMsg =
            result?['error'] as String? ??
            result?['detail'] as String? ??
            'Error desconocido en el servidor.';
        return Left(ServerFailure(message: errMsg));
      }

      return const Right(null);
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'PostgrestException en register_supplier_credit_payment_rpc: ${e.message}',
        tag: 'SUPPLIER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado al registrar pago de crédito a proveedor',
        tag: 'SUPPLIER_CREDITS_REPO',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error inesperado al registrar el pago: $e'),
      );
    }
  }
}

