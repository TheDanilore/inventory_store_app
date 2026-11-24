import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/customers/data/cache/customers_lru_cache.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customers_global_stats_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customers_page_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/recent_order_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/top_product_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/customers_repository.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_usecase.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/export_customers_pdf_usecase.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_state.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customers/customers_stats_state.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers/top_customers_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/top_customers/top_customers_state.dart';

class _FakeCustomersRepository implements CustomersRepository {
  final CustomersLruCache cache;

  _FakeCustomersRepository(this.cache);

  int getCustomersCalls = 0;
  int getStatsCalls = 0;
  int getTopCalls = 0;

  Future<Either<Failure, CustomersPageEntity>> Function({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt,
    bool forceRefresh,
  })?
  onGetCustomers;

  Future<Either<Failure, CustomersGlobalStatsEntity>> Function({
    bool forceRefresh,
  })?
  onGetStats;

  Future<Either<Failure, List<CustomerEntity>>> Function(
    int limit, {
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh,
  })?
  onGetTop;

  @override
  ({CustomersPageEntity data, bool isStale})? getCachedCustomersPage({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  }) => cache.getPage(
    limit: limit,
    offset: offset,
    query: query ?? '',
    showOnlyWithDebt: showOnlyWithDebt,
  );

  @override
  ({CustomersGlobalStatsEntity data, bool isStale})? getCachedGlobalStats() =>
      cache.getStats();

  @override
  ({List<CustomerEntity> data, bool isStale})? getCachedTopCustomers({
    required int limit,
    DateTime? startDate,
    DateTime? endDate,
  }) => cache.getTopCustomers(
    limit: limit,
    startDate: startDate,
    endDate: endDate,
  );

  @override
  void invalidateCache() => cache.invalidateAll();

  @override
  Future<Either<Failure, CustomersPageEntity>> getCustomers({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
    bool forceRefresh = false,
  }) async {
    getCustomersCalls++;
    if (onGetCustomers != null) {
      final res = await onGetCustomers!(
        limit: limit,
        offset: offset,
        query: query,
        showOnlyWithDebt: showOnlyWithDebt,
        forceRefresh: forceRefresh,
      );
      res.fold((_) {}, (page) {
        cache.putPage(
          query: query ?? '',
          showOnlyWithDebt: showOnlyWithDebt,
          offset: offset,
          limit: limit,
          data: page,
        );
      });
      return res;
    }
    return const Right(
      CustomersPageEntity(customers: [], totalCount: 0, hasMore: false),
    );
  }

  @override
  Future<Either<Failure, CustomersGlobalStatsEntity>> getGlobalStats({
    bool forceRefresh = false,
  }) async {
    getStatsCalls++;
    if (onGetStats != null) {
      final res = await onGetStats!(forceRefresh: forceRefresh);
      res.fold((_) {}, cache.putStats);
      return res;
    }
    return const Right(CustomersGlobalStatsEntity.empty());
  }

  @override
  Future<Either<Failure, List<CustomerEntity>>> getTopCustomers(
    int limit, {
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) async {
    getTopCalls++;
    if (onGetTop != null) {
      final res = await onGetTop!(
        limit,
        startDate: startDate,
        endDate: endDate,
        forceRefresh: forceRefresh,
      );
      res.fold((_) {}, (list) {
        cache.putTopCustomers(
          limit: limit,
          startDate: startDate,
          endDate: endDate,
          data: list,
        );
      });
      return res;
    }
    return const Right([]);
  }

  @override
  Future<Either<Failure, CustomerEntity>> createCustomer({
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
  }) async => Right(_sampleCustomer('c_new', fullName));

  @override
  Future<Either<Failure, CustomerEntity>> getCustomerDetail(
    String customerId,
  ) async => Right(_sampleCustomer(customerId, 'Detail'));

  @override
  Future<Either<Failure, List<RecentOrderEntity>>> getCustomerRecentOrders(
    String customerId,
  ) async => const Right([]);

  @override
  Future<Either<Failure, List<TopProductEntity>>> getCustomerTopProducts(
    String customerId,
  ) async => const Right([]);

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
    cache.invalidateAll();
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> toggleCustomerStatus(
    String customerId,
    bool isActive,
  ) async {
    cache.invalidateAll();
    return const Right(null);
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
    cache.invalidateAll();
    return Right(_sampleCustomer(customerId, fullName));
  }
}

class _FakeExportCustomersPdfUseCase extends ExportCustomersPdfUseCase {
  int calls = 0;

  @override
  Future<void> call(List<CustomerEntity> customers) async {
    calls++;
  }
}

CustomerEntity _sampleCustomer(String id, String name, {double revenue = 100}) {
  return CustomerEntity(
    id: id,
    fullName: name,
    totalRevenue: revenue,
    orderCount: 2,
    isActive: true,
  );
}

void main() {
  group('CustomersLruCache', () {
    test('evicts oldest page when exceeding maxPages (12)', () {
      final cache = CustomersLruCache();
      for (int i = 0; i < 15; i++) {
        cache.putPage(
          query: 'q$i',
          showOnlyWithDebt: false,
          offset: 0,
          limit: 20,
          data: CustomersPageEntity(
            customers: [_sampleCustomer('c$i', 'Cliente $i')],
            totalCount: 1,
            hasMore: false,
          ),
        );
      }

      // q0, q1, q2 evicted; q3..q14 retained
      expect(cache.getPage(query: 'q0'), isNull);
      expect(cache.getPage(query: 'q2'), isNull);
      expect(cache.getPage(query: 'q3'), isNotNull);
      expect(cache.getPage(query: 'q14'), isNotNull);
    });

    test('invalidateAll clears pages, stats, topCustomers, and credit cache', () {
      final cache = CustomersLruCache();
      cache.putPage(
        data: CustomersPageEntity(
          customers: [_sampleCustomer('c1', 'Ana')],
          totalCount: 1,
          hasMore: false,
        ),
        query: '',
        showOnlyWithDebt: false,
        offset: 0,
        limit: 20,
      );
      cache.putStats(
        const CustomersGlobalStatsEntity(
          totalCustomersCount: 10,
          activeCustomersCount: 8,
          inactiveCustomersCount: 2,
          totalRevenue: 500,
          totalDebt: 50,
          debtCustomersCount: 1,
        ),
      );
      cache.putTopCustomers(limit: 5, data: [_sampleCustomer('c1', 'Ana')]);
      cache.putCredit(
        'c1',
        const CustomerCreditEntity(
          id: 'cr1',
          profileId: 'p1',
          creditLimit: 500,
          currentDebt: 100,
          isActive: true,
        ),
      );

      cache.invalidateAll();

      expect(cache.getPage(), isNull);
      expect(cache.getStats(), isNull);
      expect(cache.getTopCustomers(limit: 5), isNull);
      expect(cache.getCredit('c1'), isNull);
    });
  });

  group('CustomersCubit Zero-Shimmer & Concurrency', () {
    late CustomersLruCache cache;
    late _FakeCustomersRepository repo;
    late _FakeExportCustomersPdfUseCase exportPdfUc;
    late CustomersCubit cubit;

    setUp(() {
      cache = CustomersLruCache();
      repo = _FakeCustomersRepository(cache);
      exportPdfUc = _FakeExportCustomersPdfUseCase();
      cubit = CustomersCubit(GetCustomersUseCase(repo), exportPdfUc);
    });

    tearDown(() async {
      await cubit.close();
    });

    test('ensureLoaded uses L1 cache immediately with Zero-Shimmer and 0 network calls', () async {
      cache.putPage(
        query: '',
        showOnlyWithDebt: false,
        offset: 0,
        limit: 20,
        data: CustomersPageEntity(
          customers: [_sampleCustomer('c1', 'Carlos')],
          totalCount: 1,
          hasMore: false,
        ),
      );

      final emitted = <CustomersState>[];
      final sub = cubit.stream.listen(emitted.add);

      await cubit.ensureLoaded();
      // Llamada segunda vez al volver a la ruta: debe ser completamente no-op
      await cubit.ensureLoaded();
      await Future<void>.delayed(Duration.zero);

      expect(emitted.any((s) => s is CustomersLoading), isFalse);
      expect(repo.getCustomersCalls, 0);
      expect(cubit.state, isA<CustomersLoaded>());
      final loaded = cubit.state as CustomersLoaded;
      expect(loaded.customers.first.fullName, 'Carlos');
      expect(loaded.isFromCache, isTrue);

      await sub.cancel();
    });

    test('preserves cached data and surfaces degraded banner on network failure', () async {
      repo.onGetCustomers = ({
        required limit,
        required offset,
        query,
        showOnlyWithDebt = false,
        forceRefresh = false,
      }) async {
        return Right(
          CustomersPageEntity(
            customers: [_sampleCustomer('c1', 'Lucía')],
            totalCount: 1,
            hasMore: false,
          ),
        );
      };
      await cubit.fetchCustomers(reset: true);

      // Falla la recarga forzada por pérdida de conexión
      repo.onGetCustomers = ({
        required limit,
        required offset,
        query,
        showOnlyWithDebt = false,
        forceRefresh = false,
      }) async => const Left(NetworkFailure());

      await cubit.fetchCustomers(reset: true, forceRefresh: true);

      expect(cubit.state, isA<CustomersLoaded>());
      final loaded = cubit.state as CustomersLoaded;
      expect(loaded.customers.length, 1);
      expect(loaded.customers.first.fullName, 'Lucía');
      expect(loaded.transientErrorMessage, isNotNull);
    });

    test('pagination guard prevents duplicate concurrent next-page fetches', () async {
      final completer = Completer<Either<Failure, CustomersPageEntity>>();

      repo.onGetCustomers = ({
        required limit,
        required offset,
        query,
        showOnlyWithDebt = false,
        forceRefresh = false,
      }) async {
        if (offset == 0) {
          return Right(
            CustomersPageEntity(
              customers: List.generate(
                20,
                (i) => _sampleCustomer('c_$i', 'Cliente $i'),
              ),
              totalCount: 40,
              hasMore: true,
            ),
          );
        }
        return completer.future;
      };

      await cubit.fetchCustomers(reset: true);
      expect(repo.getCustomersCalls, 1);

      // Disparar dos solicitudes de página siguiente antes de resolver la primera
      final f1 = cubit.fetchCustomers();
      final f2 = cubit.fetchCustomers();
      expect(repo.getCustomersCalls, 2);

      completer.complete(
        Right(
          CustomersPageEntity(
            customers: [_sampleCustomer('c_20', 'Cliente 20')],
            totalCount: 40,
            hasMore: true,
          ),
        ),
      );
      await Future.wait([f1, f2]);

      expect(repo.getCustomersCalls, 2);
      final loaded = cubit.state as CustomersLoaded;
      expect(loaded.customers.length, 21);
      expect(loaded.isLoadingMore, isFalse);
    });

    test('request sequence guard discards stale slower search response', () async {
      final slowCompleter = Completer<Either<Failure, CustomersPageEntity>>();
      final fastCompleter = Completer<Either<Failure, CustomersPageEntity>>();

      repo.onGetCustomers = ({
        required limit,
        required offset,
        query,
        showOnlyWithDebt = false,
        forceRefresh = false,
      }) {
        if (query == 'slow') return slowCompleter.future;
        return fastCompleter.future;
      };

      final slowFuture = cubit.fetchCustomers(reset: true, query: 'slow');
      final fastFuture = cubit.fetchCustomers(reset: true, query: 'fast');

      fastCompleter.complete(
        Right(
          CustomersPageEntity(
            customers: [_sampleCustomer('fast_1', 'Rápido')],
            totalCount: 1,
            hasMore: false,
          ),
        ),
      );
      await fastFuture;

      slowCompleter.complete(
        Right(
          CustomersPageEntity(
            customers: [_sampleCustomer('slow_1', 'Lento Obsoleto')],
            totalCount: 1,
            hasMore: false,
          ),
        ),
      );
      await slowFuture;

      final loaded = cubit.state as CustomersLoaded;
      expect(loaded.query, 'fast');
      expect(loaded.customers.single.fullName, 'Rápido');
    });
  });

  group('CustomersStatsCubit & TopCustomersCubit Zero-Shimmer', () {
    test('ensureLoaded returns cached stats and skips redundant network call', () async {
      final cache = CustomersLruCache();
      cache.putStats(
        const CustomersGlobalStatsEntity(
          totalCustomersCount: 25,
          activeCustomersCount: 22,
          inactiveCustomersCount: 3,
          totalRevenue: 15000,
          totalDebt: 450,
          debtCustomersCount: 4,
        ),
      );
      final repo = _FakeCustomersRepository(cache);
      final statsCubit = CustomersStatsCubit(GetGlobalStatsUseCase(repo));

      await statsCubit.ensureLoaded();
      await statsCubit.ensureLoaded();

      expect(repo.getStatsCalls, 0);
      expect(statsCubit.state, isA<CustomersStatsLoaded>());
      expect(
        (statsCubit.state as CustomersStatsLoaded).totalCustomersCount,
        25,
      );

      await statsCubit.close();
    });

    test('TopCustomersCubit ensureLoaded uses cache and handles failures', () async {
      final cache = CustomersLruCache();
      final repo = _FakeCustomersRepository(cache)
        ..onGetTop = (
          limit, {
          startDate,
          endDate,
          forceRefresh = false,
        }) async => const Left(NetworkFailure());

      final topCubit = TopCustomersCubit(GetTopCustomersUseCase(repo));
      await topCubit.ensureLoaded(limit: 5);
      expect(topCubit.state, isA<TopCustomersError>());

      cache.putTopCustomers(
        limit: 5,
        data: [_sampleCustomer('vip1', 'Cliente VIP', revenue: 9999)],
      );
      await topCubit.ensureLoaded(limit: 5);
      expect(topCubit.state, isA<TopCustomersLoaded>());
      expect(
        (topCubit.state as TopCustomersLoaded).topCustomers.single.fullName,
        'Cliente VIP',
      );
      // Solo 1 llamada total (la de fallo inicial; la segunda usó caché)
      expect(repo.getTopCalls, 1);

      await topCubit.close();
    });
  });
}
