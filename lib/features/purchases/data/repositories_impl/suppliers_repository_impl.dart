import 'dart:async';
import 'dart:io';
import 'package:fpdart/fpdart.dart';
import 'package:http/http.dart' show ClientException;
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/core/utils/friendly_error_message.dart';
import 'package:inventory_store_app/features/purchases/data/cache/suppliers_lru_cache.dart';
import 'package:inventory_store_app/features/purchases/data/datasources/suppliers_remote_datasource.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/suppliers_repository.dart';

@LazySingleton(as: SuppliersRepository)
class SuppliersRepositoryImpl implements SuppliersRepository {
  final SuppliersRemoteDataSource _remoteDataSource;
  final SuppliersLruCache _cache;

  static const String _tag = 'SUPPLIERS_REPO';

  SuppliersRepositoryImpl(this._remoteDataSource, this._cache);

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
      final lower = error.message.toLowerCase();
      if (error.code == '42501' || lower.contains('permiso')) {
        return const UnauthorizedFailure();
      }
      if (error.code == '23505') {
        return const ValidationFailure(
          message: 'Ya existe un proveedor con ese número de RUC/ID fiscal.',
          code: '23505',
        );
      }
      if (error.code == 'P0001' || error.code == '23514') {
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
  ({SuppliersPageEntity data, bool isStale})? getCachedSuppliersPage({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool? filterIsActive,
  }) {
    final key = SuppliersLruCache.buildKey(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
      filterIsActive: filterIsActive,
    );
    return _cache.getPage(key);
  }

  @override
  ({
    SuppliersPageEntity data,
    String searchQuery,
    bool? filterIsActive,
    int page,
    int pageSize,
    bool isStale,
  })?
  getLatestCachedSnapshot() => _cache.getLatestSnapshot();

  @override
  void invalidateCache() => _cache.invalidateAll();

  @override
  Future<Either<Failure, SuppliersPageEntity>> fetchSuppliers({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool? filterIsActive,
    bool forceRefresh = false,
  }) async {
    final key = SuppliersLruCache.buildKey(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
      filterIsActive: filterIsActive,
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
      final pageData = await _remoteDataSource.fetchSuppliersPage(
        page: page,
        pageSize: pageSize,
        searchQuery: searchQuery,
        filterIsActive: filterIsActive,
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
        filterIsActive: filterIsActive,
        page: page,
        pageSize: pageSize,
      );

      return Right(hydrated);
    } catch (e, st) {
      return Left(
        _mapFailure(e, st, 'Error al obtener directorio de proveedores'),
      );
    }
  }

  @override
  Future<Either<Failure, List<SupplierEntity>>> getActiveSuppliers() async {
    final cached = _cache.getActiveSuppliers();
    if (cached != null) {
      return Right(cached);
    }

    try {
      final list = await _remoteDataSource.getActiveSuppliers();
      _cache.putActiveSuppliers(list);
      return Right(list);
    } catch (e, st) {
      return Left(_mapFailure(e, st, 'Error al obtener proveedores activos'));
    }
  }

  @override
  Future<Either<Failure, SupplierEntity?>> toggleSupplierStatus(
    String supplierId,
    bool currentStatus,
  ) async {
    try {
      final updated = await _remoteDataSource.toggleSupplierStatus(
        supplierId,
        currentStatus,
      );
      if (updated != null) {
        _cache.patchSupplier(updated);
      } else {
        _cache.invalidateDirectory();
      }
      return Right(updated);
    } catch (e, st) {
      return Left(
        _mapFailure(
          e,
          st,
          'Error al alternar estado del proveedor $supplierId',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, List<SupplierEntity>>> bulkToggleSuppliersStatus(
    List<String> supplierIds,
  ) async {
    try {
      final updatedList = await _remoteDataSource.bulkToggleSuppliersStatus(
        supplierIds,
      );
      if (updatedList.isNotEmpty) {
        _cache.patchSuppliers(updatedList);
      } else {
        _cache.invalidateDirectory();
      }
      return Right(updatedList);
    } catch (e, st) {
      return Left(
        _mapFailure(
          e,
          st,
          'Error al alternar estado masivo de proveedores',
        ),
      );
    }
  }

  @override
  Future<Either<Failure, SupplierEntity>> createSupplier(
    SupplierEntity supplier,
  ) async {
    try {
      final created = await _remoteDataSource.createSupplier(supplier);
      _cache.invalidateDirectory();
      return Right(created);
    } catch (e, st) {
      return Left(_mapFailure(e, st, 'Error al crear proveedor'));
    }
  }

  @override
  Future<Either<Failure, SupplierEntity>> updateSupplier(
    SupplierEntity supplier,
  ) async {
    try {
      final updated = await _remoteDataSource.updateSupplier(supplier);
      _cache.patchSupplier(updated);
      return Right(updated);
    } catch (e, st) {
      return Left(
        _mapFailure(e, st, 'Error al actualizar proveedor ${supplier.id}'),
      );
    }
  }
}
