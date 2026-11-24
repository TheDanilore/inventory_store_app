import 'dart:async';
import 'dart:io';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' show ClientException;
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/app_exception.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/utils/friendly_error_message.dart';
import 'package:inventory_store_app/features/customers/data/cache/credit_movements_cache.dart';
import 'package:inventory_store_app/features/customers/data/cache/customer_credits_lru_cache.dart';
import 'package:inventory_store_app/features/customers/data/cache/customers_lru_cache.dart';
import 'package:inventory_store_app/features/customers/data/datasources/customer_credits_remote_datasource.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_list_result_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/customer_credits_repository.dart';

@LazySingleton(as: CustomerCreditsRepository)
class CustomerCreditsRepositoryImpl implements CustomerCreditsRepository {
  final CustomerCreditsRemoteDataSource _remoteDataSource;
  final CustomerCreditsLruCache _creditsCache;
  final CustomersLruCache _customersCache;

  static const String _tag = 'CUSTOMER_CREDITS_REPO';

  CustomerCreditsRepositoryImpl(
    this._remoteDataSource,
    this._creditsCache,
    this._customersCache,
  );

  Failure _mapFailure(Object error, StackTrace stackTrace, String context) {
    LoggerService.e(context, tag: _tag, error: error, stackTrace: stackTrace);

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
      final lower = error.message.toLowerCase();
      if (error.code == '42501' || lower.contains('permiso')) {
        return const UnauthorizedFailure();
      }
      if (error.code == 'P0001' ||
          error.code == '23505' ||
          error.code == '23514') {
        return ValidationFailure(
          message: FriendlyErrorMessage.format(error),
          code: error.code ?? 'VALIDATION_ERROR',
        );
      }
      if (error.code == 'P0002') {
        return NotFoundFailure(message: FriendlyErrorMessage.format(error));
      }
      return ServerFailure(
        message: FriendlyErrorMessage.format(error),
        code: error.code ?? 'POSTGREST_ERROR',
      );
    }

    if (error is AppException) {
      return Failure.from(error);
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

  void _invalidateCrossCaches({String? creditId}) {
    _creditsCache.invalidateAll();
    _customersCache.invalidateAll();
    if (creditId != null && creditId.isNotEmpty) {
      CreditMovementsCache().invalidate(creditId);
    }
  }

  @override
  ({CustomerCreditListResultEntity data, bool isStale})?
  getCachedCreditAccountsPage({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  }) {
    final page = limit > 0 ? (offset ~/ limit) + 1 : 1;
    final key = CustomerCreditsLruCache.buildKey(
      page: page,
      pageSize: limit,
      searchQuery: query ?? '',
      withDebtOnly: showOnlyWithDebt,
    );
    return _creditsCache.getPage(key);
  }

  @override
  ({
    CustomerCreditListResultEntity data,
    String searchQuery,
    bool withDebtOnly,
    int page,
    int pageSize,
    bool isStale,
  })?
  getLatestCachedSnapshot() => _creditsCache.getLatestSnapshot();

  @override
  void invalidateCache() => _creditsCache.invalidateAll();

  @override
  Future<Either<Failure, CustomerCreditListResultEntity>> getCreditAccounts({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
    bool forceRefresh = false,
  }) async {
    final page = limit > 0 ? (offset ~/ limit) + 1 : 1;
    final cleanQuery = query?.trim() ?? '';
    final key = CustomerCreditsLruCache.buildKey(
      page: page,
      pageSize: limit,
      searchQuery: cleanQuery,
      withDebtOnly: showOnlyWithDebt,
    );

    if (!forceRefresh) {
      final cached = _creditsCache.getPage(key);
      if (cached != null && !cached.isStale) {
        return Right(cached.data);
      }
    }

    try {
      final result = await _remoteDataSource.getCreditAccounts(
        limit: limit,
        offset: offset,
        query: cleanQuery,
        showOnlyWithDebt: showOnlyWithDebt,
      );
      _creditsCache.putPage(
        key: key,
        data: result,
        searchQuery: cleanQuery,
        withDebtOnly: showOnlyWithDebt,
        page: page,
        pageSize: limit,
      );
      return Right(result);
    } catch (e, st) {
      return Left(_mapFailure(e, st, 'Error en getCreditAccounts'));
    }
  }

  @override
  Future<Either<Failure, CustomerCreditEntity?>> getCreditAccountByCustomer(
    String customerId,
  ) async {
    try {
      final account = await _remoteDataSource.getCreditAccountByCustomer(
        customerId,
      );
      return Right(account);
    } catch (e, st) {
      return Left(
        _mapFailure(
          e,
          st,
          'Error en getCreditAccountByCustomer para $customerId',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<CustomerEntity>>> searchCustomersWithoutCredit(
    String query, {
    int limit = 8,
  }) async {
    try {
      final list = await _remoteDataSource.searchCustomersWithoutCredit(
        query,
        limit: limit,
      );
      return Right(list);
    } catch (e, st) {
      return Left(
        _mapFailure(e, st, 'Error en searchCustomersWithoutCredit'),
      );
    }
  }

  @override
  Future<Either<Failure, CustomerCreditEntity>> createCreditAccount({
    required String customerId,
    required double creditLimit,
  }) async {
    try {
      final created = await _remoteDataSource.createCreditAccount(
        customerId: customerId,
        creditLimit: creditLimit,
      );
      _invalidateCrossCaches(creditId: created.id);
      return Right(created);
    } catch (e, st) {
      return Left(_mapFailure(e, st, 'Error en createCreditAccount'));
    }
  }

  @override
  Future<Either<Failure, CustomerCreditEntity>> updateCreditLimit({
    required String creditId,
    required double newLimit,
  }) async {
    try {
      final updated = await _remoteDataSource.updateCreditLimit(
        creditId: creditId,
        newLimit: newLimit,
      );
      _invalidateCrossCaches(creditId: creditId);
      return Right(updated);
    } catch (e, st) {
      return Left(_mapFailure(e, st, 'Error en updateCreditLimit $creditId'));
    }
  }

  @override
  Future<Either<Failure, CustomerCreditEntity>> toggleCreditStatus(
    String creditId,
    bool isActive,
  ) async {
    try {
      final updated = await _remoteDataSource.toggleCreditStatus(
        creditId,
        isActive,
      );
      _creditsCache.patchAccount(updated);
      _customersCache.invalidateAll();
      return Right(updated);
    } catch (e, st) {
      return Left(_mapFailure(e, st, 'Error en toggleCreditStatus $creditId'));
    }
  }

  @override
  Future<Either<Failure, ({List<CreditMovementEntity> items, int totalCount})>>
  getCreditMovements({
    required String creditId,
    required int limit,
    required int offset,
    String? dateFilter,
    String? movementType,
  }) async {
    try {
      final result = await _remoteDataSource.getCreditMovements(
        creditId: creditId,
        limit: limit,
        offset: offset,
        dateFilter: dateFilter,
        movementType: movementType,
      );
      return Right(result);
    } catch (e, st) {
      return Left(
        _mapFailure(e, st, 'Error en getCreditMovements para $creditId'),
      );
    }
  }

  @override
  Future<
    Either<
      Failure,
      ({
        double totalCharged,
        double totalPaid,
        int chargeCount,
        int paymentCount,
      })
    >
  >
  getCreditMovementsTotals({
    required String creditId,
    String? dateFilter,
  }) async {
    try {
      final totals = await _remoteDataSource.getCreditMovementsTotals(
        creditId: creditId,
        dateFilter: dateFilter,
      );
      return Right(totals);
    } catch (e, st) {
      return Left(
        _mapFailure(e, st, 'Error en getCreditMovementsTotals para $creditId'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> registerPayment({
    required String customerId,
    required String creditId,
    required double amount,
    String? accountId,
    String? orderId,
    String? notes,
    String? shiftId,
    String? idempotencyKey,
  }) async {
    try {
      await _remoteDataSource.registerPayment(
        customerId: customerId,
        creditId: creditId,
        amount: amount,
        accountId: accountId,
        orderId: orderId,
        notes: notes,
        shiftId: shiftId,
        idempotencyKey: idempotencyKey,
      );
      _invalidateCrossCaches(creditId: creditId);
      return const Right(null);
    } catch (e, st) {
      return Left(
        _mapFailure(e, st, 'Error en registerPayment para crédito $creditId'),
      );
    }
  }
}
