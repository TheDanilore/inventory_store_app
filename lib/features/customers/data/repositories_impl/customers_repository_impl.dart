import 'dart:async';
import 'dart:io';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' show ClientException;
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/utils/friendly_error_message.dart';
import 'package:inventory_store_app/features/customers/data/cache/customers_lru_cache.dart';
import 'package:inventory_store_app/features/customers/data/datasources/customers_remote_datasource.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customers_global_stats_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customers_page_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/recent_order_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/top_product_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/customers_repository.dart';

@LazySingleton(as: CustomersRepository)
class CustomersRepositoryImpl implements CustomersRepository {
  final CustomersRemoteDataSource _remoteDataSource;
  final CustomersLruCache _cache;

  static const String _tag = 'CUSTOMERS_REPO';

  CustomersRepositoryImpl(this._remoteDataSource, this._cache);

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
      if (error.code == '23505') {
        return const ValidationFailure(
          message: 'Ya existe un cliente registrado con este documento.',
          code: '23505',
        );
      }
      if (error.code == 'P0001' || error.code == '23514') {
        return ValidationFailure(
          message: FriendlyErrorMessage.format(error),
          code: error.code ?? 'VALIDATION_ERROR',
        );
      }
      if (error.code == 'P0002') {
        return const NotFoundFailure(message: 'Cliente no encontrado.');
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
  ({CustomersPageEntity data, bool isStale})? getCachedCustomersPage({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  }) {
    return _cache.getPage(
      query: query ?? '',
      showOnlyWithDebt: showOnlyWithDebt,
      offset: offset,
      limit: limit,
    );
  }

  @override
  ({CustomersGlobalStatsEntity data, bool isStale})? getCachedGlobalStats() {
    return _cache.getStats();
  }

  @override
  ({List<CustomerEntity> data, bool isStale})? getCachedTopCustomers({
    required int limit,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _cache.getTopCustomers(
      limit: limit,
      startDate: startDate,
      endDate: endDate,
    );
  }

  @override
  void invalidateCache() => _cache.invalidateAll();

  @override
  Future<Either<Failure, CustomersPageEntity>> getCustomers({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
    bool forceRefresh = false,
  }) async {
    final normalizedQuery = query?.trim() ?? '';

    if (!forceRefresh) {
      final cached = _cache.getPage(
        query: normalizedQuery,
        showOnlyWithDebt: showOnlyWithDebt,
        offset: offset,
        limit: limit,
      );
      if (cached != null && !cached.isStale) {
        return Right(cached.data);
      }
    }

    try {
      final page = await _remoteDataSource.getCustomersPage(
        limit: limit,
        offset: offset,
        query: normalizedQuery,
        showOnlyWithDebt: showOnlyWithDebt,
      );

      _cache.putPage(
        query: normalizedQuery,
        showOnlyWithDebt: showOnlyWithDebt,
        offset: offset,
        limit: limit,
        data: page,
      );

      return Right(page);
    } catch (e, stack) {
      return Left(_mapFailure(e, stack, 'Error en getCustomers'));
    }
  }

  @override
  Future<Either<Failure, CustomerEntity>> getCustomerDetail(
    String customerId,
  ) async {
    try {
      final detail = await _remoteDataSource.getCustomerDetail(customerId);
      return Right(detail);
    } catch (e, stack) {
      return Left(
        _mapFailure(
          e,
          stack,
          'Error al obtener detalle de cliente $customerId',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, CustomerEntity>> createCustomer({
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
  }) async {
    try {
      final created = await _remoteDataSource.createCustomer(
        fullName: fullName,
        phone: phone,
        documentNumber: documentNumber,
        documentType: documentType,
      );
      _cache.invalidateAll();
      return Right(created);
    } catch (e, stack) {
      return Left(_mapFailure(e, stack, 'Error en createCustomer'));
    }
  }

  @override
  Future<Either<Failure, CustomerEntity>> updateCustomer({
    required String customerId,
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
    bool? isActive,
  }) async {
    try {
      final updated = await _remoteDataSource.updateCustomer(
        customerId: customerId,
        fullName: fullName,
        phone: phone,
        documentNumber: documentNumber,
        documentType: documentType,
        isActive: isActive,
      );
      _cache.invalidateAll();
      return Right(updated);
    } catch (e, stack) {
      return Left(_mapFailure(e, stack, 'Error en updateCustomer $customerId'));
    }
  }

  @override
  Future<Either<Failure, void>> saveCustomerFullProfile({
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
    try {
      await _remoteDataSource.saveCustomerFullProfile(
        customerId: customerId,
        fullName: fullName,
        phone: phone,
        documentNumber: documentNumber,
        documentType: documentType,
        isActive: isActive,
        walletAdjustDelta: walletAdjustDelta,
        currentWalletBalance: currentWalletBalance,
        hasCredit: hasCredit,
        creditExistsInDb: creditExistsInDb,
        creditId: creditId,
        creditIsActive: creditIsActive,
        newCreditLimit: newCreditLimit,
      );
      _cache.invalidateAll();
      return const Right(null);
    } catch (e, stack) {
      return Left(_mapFailure(e, stack, 'Error en saveCustomerFullProfile'));
    }
  }

  @override
  Future<Either<Failure, void>> toggleCustomerStatus(
    String customerId,
    bool isActive,
  ) async {
    try {
      await _remoteDataSource.toggleCustomerStatus(customerId, isActive);
      _cache.invalidateAll();
      return const Right(null);
    } catch (e, stack) {
      return Left(
        _mapFailure(e, stack, 'Error en toggleCustomerStatus $customerId'),
      );
    }
  }

  @override
  Future<Either<Failure, CustomersGlobalStatsEntity>> getGlobalStats({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cache.getStats();
      if (cached != null && !cached.isStale) {
        return Right(cached.data);
      }
    }

    try {
      final stats = await _remoteDataSource.getGlobalStats();
      _cache.putStats(stats);
      return Right(stats);
    } catch (e, stack) {
      return Left(_mapFailure(e, stack, 'Error en getGlobalStats'));
    }
  }

  @override
  Future<Either<Failure, List<CustomerEntity>>> getTopCustomers(
    int limit, {
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh) {
      final cached = _cache.getTopCustomers(
        limit: limit,
        startDate: startDate,
        endDate: endDate,
      );
      if (cached != null && !cached.isStale) {
        return Right(cached.data);
      }
    }

    try {
      final top = await _remoteDataSource.getTopCustomers(
        limit,
        startDate: startDate,
        endDate: endDate,
      );
      _cache.putTopCustomers(
        limit: limit,
        startDate: startDate,
        endDate: endDate,
        data: top,
      );
      return Right(top);
    } catch (e, stack) {
      return Left(_mapFailure(e, stack, 'Error en getTopCustomers'));
    }
  }

  @override
  Future<Either<Failure, List<RecentOrderEntity>>> getCustomerRecentOrders(
    String customerId,
  ) async {
    try {
      final orders = await _remoteDataSource.getCustomerRecentOrders(
        customerId,
      );
      return Right(orders);
    } catch (e, stack) {
      return Left(
        _mapFailure(
          e,
          stack,
          'Error al cargar órdenes recientes de $customerId',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<TopProductEntity>>> getCustomerTopProducts(
    String customerId,
  ) async {
    try {
      final products = await _remoteDataSource.getCustomerTopProducts(
        customerId,
      );
      return Right(products);
    } catch (e, stack) {
      return Left(
        _mapFailure(e, stack, 'Error al cargar top productos de $customerId'),
      );
    }
  }
}
