import 'dart:async';
import 'dart:io';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' show ClientException;
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/utils/friendly_error_message.dart';
import 'package:inventory_store_app/features/purchases/data/cache/supplier_credits_lru_cache.dart';
import 'package:inventory_store_app/features/purchases/data/datasources/supplier_credits_remote_datasource.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credits_repository.dart';

@LazySingleton(as: SupplierCreditsRepository)
class SupplierCreditsRepositoryImpl implements SupplierCreditsRepository {
  final SupplierCreditsRemoteDataSource _remoteDataSource;
  final SupplierCreditsLruCache _cache;

  static const String _tag = 'SUPPLIER_CREDITS_REPO';

  SupplierCreditsRepositoryImpl(this._remoteDataSource, this._cache);

  Failure _mapFailure(Object error, StackTrace stackTrace, String context) {
    LoggerService.e(
      context,
      tag: _tag,
      error: error,
      stackTrace: stackTrace,
    );

    if (error is SocketException ||
        error is TimeoutException ||
        error is ClientException) {
      return const NetworkFailure();
    }

    if (error is AuthException) {
      if (error.statusCode == '401' ||
          error.message.toLowerCase().contains('unauthorized')) {
        return const UnauthorizedFailure();
      }
      return ServerFailure(
        message: FriendlyErrorMessage.format(error),
        code: error.statusCode ?? 'AUTH_ERROR',
      );
    }

    if (error is PostgrestException) {
      final msgLower = error.message.toLowerCase();
      if (error.code == '42501' || msgLower.contains('permiso')) {
        return const UnauthorizedFailure();
      }
      if (error.code == 'P0001' ||
          error.code == '23514' ||
          error.code == '23505') {
        return ValidationFailure(
          message: FriendlyErrorMessage.format(error),
          code: error.code ?? 'VALIDATION_ERROR',
        );
      }
      return ServerFailure(
        message: FriendlyErrorMessage.format(error),
        code: error.code ?? 'POSTGREST_ERROR',
      );
    }

    final raw = error.toString().toLowerCase();
    if (raw.contains('socketexception') ||
        raw.contains('failed host lookup') ||
        raw.contains('clientexception') ||
        raw.contains('timed out')) {
      return const NetworkFailure();
    }

    return Failure.from(error);
  }

  @override
  ({SupplierCreditsPageEntity data, bool isStale})? getCachedAccountsPage({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool withDebtOnly = false,
  }) {
    final key = SupplierCreditsLruCache.buildKey(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
      withDebtOnly: withDebtOnly,
    );
    return _cache.getPage(key);
  }

  @override
  ({
    SupplierCreditsPageEntity data,
    String searchQuery,
    bool withDebtOnly,
    int page,
    int pageSize,
    bool isStale,
  })?
  getLatestCachedSnapshot() {
    return _cache.getLatestSnapshot();
  }

  @override
  void invalidateCache() => _cache.invalidateAll();

  @override
  Future<Either<Failure, SupplierCreditsPageEntity>> fetchAccountsPaginated({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool withDebtOnly = false,
    bool forceRefresh = false,
  }) async {
    final key = SupplierCreditsLruCache.buildKey(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
      withDebtOnly: withDebtOnly,
    );

    if (!forceRefresh) {
      final cached = _cache.getPage(key);
      if (cached != null && !cached.isStale) {
        return Right(cached.data);
      }
    }

    try {
      final validStats =
          forceRefresh ? null : _cache.getValidStats(searchQuery);
      final pageData = await _remoteDataSource.fetchAccountsPage(
        page: page,
        pageSize: pageSize,
        searchQuery: searchQuery,
        withDebtOnly: withDebtOnly,
        includeStats: validStats == null || forceRefresh,
      );

      final hydrated =
          pageData.stats == null && validStats != null
              ? pageData.copyWith(stats: validStats)
              : pageData;

      _cache.putPage(
        key: key,
        data: hydrated,
        searchQuery: searchQuery,
        withDebtOnly: withDebtOnly,
        page: page,
        pageSize: pageSize,
      );

      return Right(hydrated);
    } catch (e, st) {
      return Left(
        _mapFailure(e, st, 'Error al obtener cuentas de crédito paginadas'),
      );
    }
  }

  @override
  Future<Either<Failure, SupplierCreditEntity?>> toggleAccountStatus(
    String creditId,
    bool currentStatus,
  ) async {
    try {
      final updated = await _remoteDataSource.toggleAccountStatus(
        creditId,
        currentStatus,
      );
      if (updated != null) {
        _cache.patchCredit(updated);
      } else {
        _cache.invalidateAll();
      }
      return Right(updated);
    } catch (e, st) {
      return Left(
        _mapFailure(e, st, 'Error al alternar estado del crédito $creditId'),
      );
    }
  }

  @override
  Future<Either<Failure, SupplierCreditEntity?>> saveAccount({
    required String? creditId,
    required String supplierId,
    required double creditLimit,
    String? adminProfileId,
  }) async {
    try {
      final updated = await _remoteDataSource.saveAccount(
        creditId: creditId,
        supplierId: supplierId,
        creditLimit: creditLimit,
      );
      if (updated != null) {
        _cache.patchCredit(updated);
      } else {
        _cache.invalidateAll();
      }
      return Right(updated);
    } catch (e, st) {
      return Left(
        _mapFailure(
          e,
          st,
          'Error al guardar cuenta de crédito para proveedor $supplierId',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, SupplierCreditEntity?>> registerPayment({
    required String supplierId,
    required String creditId,
    required double amount,
    required String? accountId,
    required String? orderId,
    required String notes,
    required String? shiftId,
    String? adminProfileId,
    String? idempotencyKey,
  }) async {
    try {
      final updated = await _remoteDataSource.registerPayment(
        supplierId: supplierId,
        creditId: creditId,
        amount: amount,
        accountId: accountId,
        orderId: orderId,
        notes: notes,
        shiftId: shiftId,
        adminProfileId: adminProfileId,
        idempotencyKey: idempotencyKey,
      );
      if (updated != null) {
        _cache.patchCredit(updated);
      }
      return Right(updated);
    } catch (e, st) {
      return Left(
        _mapFailure(
          e,
          st,
          'Error al registrar pago de crédito a proveedor $supplierId',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<SupplierCandidateEntity>>>
  searchAvailableSuppliers(String query) async {
    try {
      final list = await _remoteDataSource.searchAvailableSuppliers(query);
      return Right(list);
    } catch (e, st) {
      return Left(
        _mapFailure(e, st, 'Error buscando proveedores disponibles: $query'),
      );
    }
  }

  @override
  Future<Either<Failure, List<PendingPurchaseOrderEntity>>>
  getPendingPurchaseOrdersTyped(String supplierId) async {
    try {
      final list = await _remoteDataSource.getPendingPurchaseOrders(supplierId);
      return Right(list);
    } catch (e, st) {
      return Left(
        _mapFailure(
          e,
          st,
          'Error obteniendo órdenes pendientes para proveedor $supplierId',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<SupplierFinancialAccountOption>>>
  getFinancialAccounts() async {
    try {
      final list = await _remoteDataSource.getFinancialAccounts();
      return Right(list);
    } catch (e, st) {
      return Left(
        _mapFailure(e, st, 'Error obteniendo cuentas financieras activas'),
      );
    }
  }

  @override
  Future<Either<Failure, ActiveCashShiftEntity?>> getActiveCashShiftTyped(
    String accountId,
  ) async {
    try {
      final shift = await _remoteDataSource.getActiveCashShift(accountId);
      return Right(shift);
    } catch (e, st) {
      return Left(
        _mapFailure(
          e,
          st,
          'Error obteniendo turno activo para la cuenta $accountId',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> searchSuppliers(
    String query,
    Set<String> existingSupplierIds,
  ) async {
    try {
      final list = await _remoteDataSource.searchSuppliersLegacy(
        query,
        existingSupplierIds,
      );
      return Right(list);
    } catch (e, st) {
      return Left(
        _mapFailure(e, st, 'Error buscando proveedores con query: $query'),
      );
    }
  }

  @override
  Future<Either<Failure, Set<String>>> getExistingCreditSupplierIds({
    String? excludeSupplierId,
  }) async {
    try {
      final ids = await _remoteDataSource.getExistingCreditSupplierIds(
        excludeSupplierId: excludeSupplierId,
      );
      return Right(ids);
    } catch (e, st) {
      return Left(
        _mapFailure(
          e,
          st,
          'Error obteniendo IDs de proveedores con crédito existente',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getPendingPurchaseOrders(
    String supplierId,
  ) async {
    try {
      final list = await _remoteDataSource.getPendingPurchaseOrdersRaw(
        supplierId,
      );
      return Right(list);
    } catch (e, st) {
      return Left(
        _mapFailure(
          e,
          st,
          'Error obteniendo órdenes pendientes para el proveedor $supplierId',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>?>> getActiveCashShift(
    String accountId,
  ) async {
    try {
      final data = await _remoteDataSource.getActiveCashShiftRaw(accountId);
      return Right(data);
    } catch (e, st) {
      return Left(
        _mapFailure(
          e,
          st,
          'Error obteniendo turno activo para la cuenta $accountId',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, String?>> getAdminProfileId() async {
    try {
      final id = await _remoteDataSource.getAdminProfileId();
      return Right(id);
    } catch (e, st) {
      return Left(
        _mapFailure(e, st, 'Error obteniendo ID de perfil de administrador'),
      );
    }
  }
}
