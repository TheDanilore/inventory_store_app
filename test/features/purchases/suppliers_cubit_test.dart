import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/data/cache/suppliers_lru_cache.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/suppliers_repository.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/bulk_toggle_suppliers_status_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/fetch_suppliers_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/save_supplier_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/toggle_supplier_status_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/suppliers/suppliers_state.dart';

class _FakeSuppliersRepository implements SuppliersRepository {
  final SuppliersLruCache cache;
  _FakeSuppliersRepository(this.cache);

  int fetchCalls = 0;
  int bulkCalls = 0;

  Future<Either<Failure, SuppliersPageEntity>> Function({
    required int page,
    required int pageSize,
    required String searchQuery,
    required bool? filterIsActive,
    required bool forceRefresh,
  })?
  onFetch;

  Future<Either<Failure, List<SupplierEntity>>> Function(List<String> ids)?
  onBulkToggle;

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
    return cache.getPage(key);
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
  getLatestCachedSnapshot() => cache.getLatestSnapshot();

  @override
  void invalidateCache() => cache.invalidateAll();

  @override
  Future<Either<Failure, SuppliersPageEntity>> fetchSuppliers({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool? filterIsActive,
    bool forceRefresh = false,
  }) async {
    fetchCalls++;
    if (onFetch != null) {
      final res = await onFetch!(
        page: page,
        pageSize: pageSize,
        searchQuery: searchQuery,
        filterIsActive: filterIsActive,
        forceRefresh: forceRefresh,
      );
      res.fold((_) {}, (data) {
        final key = SuppliersLruCache.buildKey(
          page: page,
          pageSize: pageSize,
          searchQuery: searchQuery,
          filterIsActive: filterIsActive,
        );
        cache.putPage(
          key: key,
          data: data,
          searchQuery: searchQuery,
          filterIsActive: filterIsActive,
          page: page,
          pageSize: pageSize,
        );
      });
      return res;
    }
    return const Right(SuppliersPageEntity(suppliers: [], totalCount: 0));
  }

  @override
  Future<Either<Failure, List<SupplierEntity>>> bulkToggleSuppliersStatus(
    List<String> supplierIds,
  ) async {
    bulkCalls++;
    if (onBulkToggle != null) {
      final res = await onBulkToggle!(supplierIds);
      res.fold((_) {}, cache.patchSuppliers);
      return res;
    }
    return const Right([]);
  }

  @override
  Future<Either<Failure, SupplierEntity>> createSupplier(
    SupplierEntity supplier,
  ) async => Right(supplier);

  @override
  Future<Either<Failure, List<SupplierEntity>>> getActiveSuppliers() async =>
      const Right([]);

  @override
  Future<Either<Failure, SupplierEntity?>> toggleSupplierStatus(
    String supplierId,
    bool currentStatus,
  ) async => const Right(null);

  @override
  Future<Either<Failure, SupplierEntity>> updateSupplier(
    SupplierEntity supplier,
  ) async => Right(supplier);
}

SupplierEntity _sampleSupplier(String id, {bool isActive = true}) {
  return SupplierEntity(
    id: id,
    name: 'Proveedor $id',
    taxId: '2011111111$id',
    isActive: isActive,
  );
}

SuppliersCubit _buildCubit(_FakeSuppliersRepository repo) {
  return SuppliersCubit(
    fetchSuppliersUseCase: FetchSuppliersUseCase(repo),
    toggleSupplierStatusUseCase: ToggleSupplierStatusUseCase(repo),
    bulkToggleSuppliersStatusUseCase: BulkToggleSuppliersStatusUseCase(repo),
    saveSupplierUseCase: SaveSupplierUseCase(repo),
  );
}

void main() {
  group('SuppliersCubit Zero-Shimmer, Server Filters & ACID Bulk', () {
    test(
      '1. Hidrata en Frame 0 sin Shimmer ni llamada de red al recrear Cubit con caché L1 fresca',
      () async {
        final cache = SuppliersLruCache();
        final repo = _FakeSuppliersRepository(cache);
        repo.onFetch =
            ({
              required page,
              required pageSize,
              required searchQuery,
              required filterIsActive,
              required forceRefresh,
            }) async => Right(
              SuppliersPageEntity(
                suppliers: [_sampleSupplier('1')],
                totalCount: 1,
                stats: const SupplierStatsEntity(
                  totalSuppliers: 1,
                  activeSuppliers: 1,
                  withTaxIdCount: 1,
                ),
              ),
            );

        final firstCubit = _buildCubit(repo);
        await Future<void>.delayed(Duration.zero);
        expect(repo.fetchCalls, 1);
        await firstCubit.close();

        final secondCubit = _buildCubit(repo);
        expect(secondCubit.state.status, SuppliersLoadStatus.loaded);
        expect(secondCubit.state.isColdLoading, isFalse);
        expect(secondCubit.state.isFromCache, isTrue);
        expect(secondCubit.state.isRevalidating, isFalse);
        expect(secondCubit.state.suppliers.single.id, '1');
        expect(repo.fetchCalls, 1);
        await secondCubit.close();
      },
    );

    test(
      '2. Revalidación SWR preserva lista visible con isRevalidating == true y sin coldLoading',
      () async {
        final cache = SuppliersLruCache();
        final repo = _FakeSuppliersRepository(cache);
        cache.putPage(
          key: SuppliersLruCache.buildKey(
            page: 0,
            pageSize: 15,
            searchQuery: '',
            filterIsActive: null,
          ),
          data: SuppliersPageEntity(
            suppliers: [_sampleSupplier('1', isActive: true)],
            totalCount: 1,
            stats: const SupplierStatsEntity(totalSuppliers: 1, activeSuppliers: 1),
          ),
          searchQuery: '',
          filterIsActive: null,
          page: 0,
          pageSize: 15,
        );

        final completer = Completer<Either<Failure, SuppliersPageEntity>>();
        repo.onFetch =
            ({
              required page,
              required pageSize,
              required searchQuery,
              required filterIsActive,
              required forceRefresh,
            }) => completer.future;

        final cubit = _buildCubit(repo);
        unawaited(cubit.loadSuppliers(forceRefresh: true));
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.isColdLoading, isFalse);
        expect(cubit.state.isRevalidating, isTrue);
        expect(cubit.state.suppliers.single.isActive, isTrue);

        completer.complete(
          Right(
            SuppliersPageEntity(
              suppliers: [_sampleSupplier('1', isActive: false)],
              totalCount: 1,
              stats: const SupplierStatsEntity(
                totalSuppliers: 1,
                inactiveSuppliers: 1,
              ),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.isRevalidating, isFalse);
        expect(cubit.state.suppliers.single.isActive, isFalse);
        await cubit.close();
      },
    );

    test('3. Cálculo matemático exacto de totalPages con pageSize = 15', () {
      expect(const SuppliersState(totalCount: 0).totalPages, 1);
      expect(const SuppliersState(totalCount: 15).totalPages, 1);
      expect(const SuppliersState(totalCount: 16).totalPages, 2);
      expect(const SuppliersState(totalCount: 24).totalPages, 2);
      expect(const SuppliersState(totalCount: 31).totalPages, 3);
    });

    test(
      '4. Filtro setFilterIsActive consulta al servidor y preserva KPIs globales exactos',
      () async {
        final cache = SuppliersLruCache();
        final repo = _FakeSuppliersRepository(cache);
        repo.onFetch = ({
          required page,
          required pageSize,
          required searchQuery,
          required filterIsActive,
          required forceRefresh,
        }) async {
          if (filterIsActive == false) {
            return Right(
              SuppliersPageEntity(
                suppliers: [_sampleSupplier('inact', isActive: false)],
                totalCount: 1,
                stats: const SupplierStatsEntity(
                  totalSuppliers: 50,
                  activeSuppliers: 49,
                  inactiveSuppliers: 1,
                  withTaxIdCount: 45,
                ),
              ),
            );
          }
          return Right(
            SuppliersPageEntity(
              suppliers: [_sampleSupplier('act', isActive: true)],
              totalCount: 50,
              stats: const SupplierStatsEntity(
                totalSuppliers: 50,
                activeSuppliers: 49,
                inactiveSuppliers: 1,
                withTaxIdCount: 45,
              ),
            ),
          );
        };

        final cubit = _buildCubit(repo);
        await Future<void>.delayed(Duration.zero);

        cubit.setFilterIsActive(false);
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.filterIsActive, isFalse);
        expect(cubit.state.suppliers.single.id, 'inact');
        expect(cubit.state.totalCount, 1);
        expect(cubit.state.stats.totalSuppliers, 50);
        expect(cubit.state.stats.activeSuppliers, 49);
        await cubit.close();
      },
    );

    test(
      '5. Sequence guard descarta respuestas fuera de orden al buscar rápido',
      () async {
        final cache = SuppliersLruCache();
        final repo = _FakeSuppliersRepository(cache);
        final slowFirst = Completer<Either<Failure, SuppliersPageEntity>>();
        final fastSecond = Completer<Either<Failure, SuppliersPageEntity>>();

        repo.onFetch = ({
          required page,
          required pageSize,
          required searchQuery,
          required filterIsActive,
          required forceRefresh,
        }) {
          if (searchQuery == 'lento') return slowFirst.future;
          if (searchQuery == 'rapido') return fastSecond.future;
          return Future.value(
            const Right(SuppliersPageEntity(suppliers: [], totalCount: 0)),
          );
        };

        final cubit = _buildCubit(repo);
        await Future<void>.delayed(Duration.zero);

        cubit.setSearchQuery('lento');
        cubit.setSearchQuery('rapido');

        fastSecond.complete(
          Right(
            SuppliersPageEntity(
              suppliers: [_sampleSupplier('rapido')],
              totalCount: 1,
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.suppliers.single.id, 'rapido');

        slowFirst.complete(
          Right(
            SuppliersPageEntity(
              suppliers: [_sampleSupplier('lento')],
              totalCount: 1,
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.suppliers.single.id, 'rapido');
        await cubit.close();
      },
    );

    test(
      '6. ErrorCold se mantiene en estado error (nunca lista vacía); ErrorDegraded conserva caché',
      () async {
        // ErrorCold
        final coldCache = SuppliersLruCache();
        final coldRepo = _FakeSuppliersRepository(coldCache);
        coldRepo.onFetch =
            ({
              required page,
              required pageSize,
              required searchQuery,
              required filterIsActive,
              required forceRefresh,
            }) async => const Left(NetworkFailure());

        final coldCubit = _buildCubit(coldRepo);
        await Future<void>.delayed(Duration.zero);
        expect(coldCubit.state.status, SuppliersLoadStatus.error);
        expect(coldCubit.state.suppliers, isEmpty);
        expect(coldCubit.state.loadFailure, isA<NetworkFailure>());
        await coldCubit.close();

        // ErrorDegraded
        final warmCache = SuppliersLruCache();
        warmCache.putPage(
          key: SuppliersLruCache.buildKey(
            page: 0,
            pageSize: 15,
            searchQuery: '',
            filterIsActive: null,
          ),
          data: SuppliersPageEntity(
            suppliers: [_sampleSupplier('cached')],
            totalCount: 1,
          ),
          searchQuery: '',
          filterIsActive: null,
          page: 0,
          pageSize: 15,
        );
        final warmRepo = _FakeSuppliersRepository(warmCache);
        warmRepo.onFetch =
            ({
              required page,
              required pageSize,
              required searchQuery,
              required filterIsActive,
              required forceRefresh,
            }) async => const Left(NetworkFailure());

        final warmCubit = _buildCubit(warmRepo);
        await warmCubit.loadSuppliers(forceRefresh: true);
        expect(warmCubit.state.status, SuppliersLoadStatus.loaded);
        expect(warmCubit.state.suppliers.single.id, 'cached');
        expect(warmCubit.state.loadFailure, isA<NetworkFailure>());
        await warmCubit.close();
      },
    );

    test(
      '7. bulkToggleSuppliersStatus ejecuta 1 llamada atómica sin Lost Updates',
      () async {
        final cache = SuppliersLruCache();
        final repo = _FakeSuppliersRepository(cache);
        final s1 = _sampleSupplier('1', isActive: true);
        final s2 = _sampleSupplier('2', isActive: false);

        repo.onFetch =
            ({
              required page,
              required pageSize,
              required searchQuery,
              required filterIsActive,
              required forceRefresh,
            }) async => Right(
              SuppliersPageEntity(
                suppliers: [s1, s2],
                totalCount: 2,
                stats: const SupplierStatsEntity(
                  totalSuppliers: 2,
                  activeSuppliers: 1,
                  inactiveSuppliers: 1,
                ),
              ),
            );
        repo.onBulkToggle = (ids) async {
          return Right([
            s1.copyWith(isActive: false),
            s2.copyWith(isActive: true),
          ]);
        };

        final cubit = _buildCubit(repo);
        await Future<void>.delayed(Duration.zero);

        await cubit.bulkToggleSuppliersStatus([s1, s2]);

        expect(repo.bulkCalls, 1);
        expect(cubit.state.mutationStatus, SupplierMutationStatus.success);
        expect(cubit.state.mutationKind, SupplierMutationKind.bulkToggle);
        expect(cubit.state.suppliers[0].isActive, isFalse);
        expect(cubit.state.suppliers[1].isActive, isTrue);
        await cubit.close();
      },
    );
  });
}
