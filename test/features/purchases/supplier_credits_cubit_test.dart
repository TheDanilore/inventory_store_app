import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/data/cache/supplier_credits_lru_cache.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credits_repository.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/fetch_supplier_credits_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_active_cash_shift_typed_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_financial_accounts_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/get_pending_purchase_orders_typed_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/register_supplier_payment_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/toggle_supplier_credit_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_state.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_payment_form_cubit.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_payment_form_state.dart';

class _FakeSupplierCreditsRepository implements SupplierCreditsRepository {
  final SupplierCreditsLruCache cache;

  _FakeSupplierCreditsRepository(this.cache);

  int fetchCalls = 0;
  Future<Either<Failure, SupplierCreditsPageEntity>> Function({
    required int page,
    required int pageSize,
    required String searchQuery,
    required bool withDebtOnly,
    required bool forceRefresh,
  })?
  onFetch;

  Either<Failure, ActiveCashShiftEntity?> shiftResponse = const Right(null);
  Either<Failure, List<PendingPurchaseOrderEntity>> pendingOrdersResponse =
      const Right([]);
  Either<Failure, List<SupplierFinancialAccountOption>> accountsResponse =
      const Right([
        SupplierFinancialAccountOption(
          id: 'acc-caja-1',
          name: 'Caja Principal',
          type: 'CAJA',
          balance: 1500,
        ),
      ]);

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
    return cache.getPage(key);
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
  getLatestCachedSnapshot() => cache.getLatestSnapshot();

  @override
  void invalidateCache() => cache.invalidateAll();

  @override
  Future<Either<Failure, SupplierCreditsPageEntity>> fetchAccountsPaginated({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool withDebtOnly = false,
    bool forceRefresh = false,
  }) async {
    fetchCalls++;
    if (onFetch != null) {
      final res = await onFetch!(
        page: page,
        pageSize: pageSize,
        searchQuery: searchQuery,
        withDebtOnly: withDebtOnly,
        forceRefresh: forceRefresh,
      );
      res.fold((_) {}, (data) {
        final key = SupplierCreditsLruCache.buildKey(
          page: page,
          pageSize: pageSize,
          searchQuery: searchQuery,
          withDebtOnly: withDebtOnly,
        );
        cache.putPage(
          key: key,
          data: data,
          searchQuery: searchQuery,
          withDebtOnly: withDebtOnly,
          page: page,
          pageSize: pageSize,
        );
      });
      return res;
    }
    return const Right(
      SupplierCreditsPageEntity(accounts: [], totalCount: 0),
    );
  }

  @override
  Future<Either<Failure, ActiveCashShiftEntity?>> getActiveCashShiftTyped(
    String accountId,
  ) async => shiftResponse;

  @override
  Future<Either<Failure, List<SupplierFinancialAccountOption>>>
  getFinancialAccounts() async => accountsResponse;

  @override
  Future<Either<Failure, List<PendingPurchaseOrderEntity>>>
  getPendingPurchaseOrdersTyped(String supplierId) async =>
      pendingOrdersResponse;

  @override
  Future<Either<Failure, SupplierCreditEntity?>> toggleAccountStatus(
    String creditId,
    bool currentStatus,
  ) async => const Right(null);

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
  }) async => const Right(null);

  @override
  Future<Either<Failure, SupplierCreditEntity?>> saveAccount({
    required String? creditId,
    required String supplierId,
    required double creditLimit,
    String? adminProfileId,
  }) async => const Right(null);

  @override
  Future<Either<Failure, List<SupplierCandidateEntity>>>
  searchAvailableSuppliers(String query) async => const Right([]);

  @override
  Future<Either<Failure, Map<String, dynamic>?>> getActiveCashShift(
    String accountId,
  ) async => const Right(null);

  @override
  Future<Either<Failure, String?>> getAdminProfileId() async =>
      const Right(null);

  @override
  Future<Either<Failure, Set<String>>> getExistingCreditSupplierIds({
    String? excludeSupplierId,
  }) async => const Right({});

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getPendingPurchaseOrders(
    String supplierId,
  ) async => const Right([]);

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> searchSuppliers(
    String query,
    Set<String> existingSupplierIds,
  ) async => const Right([]);
}

SupplierCreditEntity _sampleCredit(String id, {double debt = 250}) {
  return SupplierCreditEntity(
    creditId: id,
    supplierId: 'sup-$id',
    supplierName: 'Proveedor $id',
    supplierTaxId: '20123456789',
    creditLimit: 1000,
    currentDebt: debt,
    isActive: true,
  );
}

void main() {
  group('SupplierCreditsCubit Zero-Shimmer & State Integrity', () {
    test(
      '1. Hidrata en Frame 0 sin Shimmer ni llamada de red al recrear Cubit con caché L1 fresca',
      () async {
        final cache = SupplierCreditsLruCache();
        final repo = _FakeSupplierCreditsRepository(cache);
        final pageData = SupplierCreditsPageEntity(
          accounts: [_sampleCredit('1')],
          totalCount: 1,
          stats: const SupplierCreditStatsEntity(
            totalDebt: 250,
            activeAccounts: 1,
            debtCount: 1,
          ),
        );
        repo.onFetch =
            ({
              required page,
              required pageSize,
              required searchQuery,
              required withDebtOnly,
              required forceRefresh,
            }) async => Right(pageData);

        final firstCubit = SupplierCreditsCubit(
          fetchSupplierCreditsUseCase: FetchSupplierCreditsUseCase(repo),
          toggleSupplierCreditUseCase: ToggleSupplierCreditUseCase(repo),
          registerSupplierPaymentUseCase: RegisterSupplierPaymentUseCase(repo),
        );
        await Future<void>.delayed(Duration.zero);
        expect(repo.fetchCalls, 1);
        await firstCubit.close();

        // Al salir y regresar a la pantalla se crea un nuevo Cubit:
        final secondCubit = SupplierCreditsCubit(
          fetchSupplierCreditsUseCase: FetchSupplierCreditsUseCase(repo),
          toggleSupplierCreditUseCase: ToggleSupplierCreditUseCase(repo),
          registerSupplierPaymentUseCase: RegisterSupplierPaymentUseCase(repo),
        );

        expect(secondCubit.state.status, SupplierCreditsLoadStatus.loaded);
        expect(secondCubit.state.isColdLoading, isFalse);
        expect(secondCubit.state.isFromCache, isTrue);
        expect(secondCubit.state.isRevalidating, isFalse);
        expect(secondCubit.state.accounts.length, 1);
        expect(repo.fetchCalls, 1); // 0 requests adicionales de red
        await secondCubit.close();
      },
    );

    test(
      '2. Revalidación SWR: sirve caché inmediatamente sin borrar lista cuando se refresca en background',
      () async {
        final cache = SupplierCreditsLruCache();
        final repo = _FakeSupplierCreditsRepository(cache);
        final initial = SupplierCreditsPageEntity(
          accounts: [_sampleCredit('1', debt: 200)],
          totalCount: 1,
          stats: const SupplierCreditStatsEntity(totalDebt: 200),
        );
        cache.putPage(
          key: SupplierCreditsLruCache.buildKey(
            page: 0,
            pageSize: 15,
            searchQuery: '',
            withDebtOnly: false,
          ),
          data: initial,
          searchQuery: '',
          withDebtOnly: false,
          page: 0,
          pageSize: 15,
        );

        final completer =
            Completer<Either<Failure, SupplierCreditsPageEntity>>();
        repo.onFetch =
            ({
              required page,
              required pageSize,
              required searchQuery,
              required withDebtOnly,
              required forceRefresh,
            }) => completer.future;

        final cubit = SupplierCreditsCubit(
          fetchSupplierCreditsUseCase: FetchSupplierCreditsUseCase(repo),
          toggleSupplierCreditUseCase: ToggleSupplierCreditUseCase(repo),
          registerSupplierPaymentUseCase: RegisterSupplierPaymentUseCase(repo),
        );

        unawaited(cubit.loadAccounts(forceRefresh: true));
        await Future<void>.delayed(Duration.zero);

        // Mientras revalida, los datos cacheados siguen visibles y NO hay coldLoading
        expect(cubit.state.isColdLoading, isFalse);
        expect(cubit.state.isRevalidating, isTrue);
        expect(cubit.state.accounts.first.currentDebt, 200);

        completer.complete(
          Right(
            SupplierCreditsPageEntity(
              accounts: [_sampleCredit('1', debt: 100)],
              totalCount: 1,
              stats: const SupplierCreditStatsEntity(totalDebt: 100),
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.isRevalidating, isFalse);
        expect(cubit.state.accounts.first.currentDebt, 100);
        await cubit.close();
      },
    );

    test('3. Cálculo matemático exacto de totalPages con pageSize = 15', () {
      expect(const SupplierCreditsState(totalCount: 0).totalPages, 1);
      expect(const SupplierCreditsState(totalCount: 15).totalPages, 1);
      expect(const SupplierCreditsState(totalCount: 16).totalPages, 2);
      expect(const SupplierCreditsState(totalCount: 24).totalPages, 2);
      expect(const SupplierCreditsState(totalCount: 31).totalPages, 3);
    });

    test(
      '4. Sequence guard descarta respuestas fuera de orden al cambiar filtros rápido',
      () async {
        final cache = SupplierCreditsLruCache();
        final repo = _FakeSupplierCreditsRepository(cache);
        final slowFirst =
            Completer<Either<Failure, SupplierCreditsPageEntity>>();
        final fastSecond =
            Completer<Either<Failure, SupplierCreditsPageEntity>>();

        repo.onFetch = ({
          required page,
          required pageSize,
          required searchQuery,
          required withDebtOnly,
          required forceRefresh,
        }) {
          if (searchQuery == 'lento') return slowFirst.future;
          if (searchQuery == 'rapido') return fastSecond.future;
          return Future.value(
            const Right(SupplierCreditsPageEntity(accounts: [], totalCount: 0)),
          );
        };

        final cubit = SupplierCreditsCubit(
          fetchSupplierCreditsUseCase: FetchSupplierCreditsUseCase(repo),
          toggleSupplierCreditUseCase: ToggleSupplierCreditUseCase(repo),
          registerSupplierPaymentUseCase: RegisterSupplierPaymentUseCase(repo),
        );
        await Future<void>.delayed(Duration.zero);

        cubit.setSearchQuery('lento');
        cubit.setSearchQuery('rapido');

        fastSecond.complete(
          Right(
            SupplierCreditsPageEntity(
              accounts: [_sampleCredit('rapido')],
              totalCount: 1,
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.searchQuery, 'rapido');
        expect(cubit.state.accounts.single.creditId, 'rapido');

        // Ahora llega la respuesta lenta y debe ser ignorada
        slowFirst.complete(
          Right(
            SupplierCreditsPageEntity(
              accounts: [_sampleCredit('lento')],
              totalCount: 1,
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.searchQuery, 'rapido');
        expect(cubit.state.accounts.single.creditId, 'rapido');
        await cubit.close();
      },
    );

    test(
      '5. ErrorDegraded conserva datos cacheados visibles ante NetworkFailure',
      () async {
        final cache = SupplierCreditsLruCache();
        final repo = _FakeSupplierCreditsRepository(cache);
        cache.putPage(
          key: SupplierCreditsLruCache.buildKey(
            page: 0,
            pageSize: 15,
            searchQuery: '',
            withDebtOnly: false,
          ),
          data: SupplierCreditsPageEntity(
            accounts: [_sampleCredit('cached')],
            totalCount: 1,
          ),
          searchQuery: '',
          withDebtOnly: false,
          page: 0,
          pageSize: 15,
        );

        repo.onFetch =
            ({
              required page,
              required pageSize,
              required searchQuery,
              required withDebtOnly,
              required forceRefresh,
            }) async => const Left(NetworkFailure());

        final cubit = SupplierCreditsCubit(
          fetchSupplierCreditsUseCase: FetchSupplierCreditsUseCase(repo),
          toggleSupplierCreditUseCase: ToggleSupplierCreditUseCase(repo),
          registerSupplierPaymentUseCase: RegisterSupplierPaymentUseCase(repo),
        );

        await cubit.loadAccounts(forceRefresh: true);

        expect(cubit.state.status, SupplierCreditsLoadStatus.loaded);
        expect(cubit.state.accounts.single.creditId, 'cached');
        expect(cubit.state.loadFailure, isA<NetworkFailure>());
        await cubit.close();
      },
    );
  });

  group('SupplierPaymentFormCubit Shift Error & Idempotency', () {
    test(
      '6. Fallo de red al consultar turno emite CashShiftStatus.error (nunca open) y UUID v4 válido',
      () async {
        final cache = SupplierCreditsLruCache();
        final repo =
            _FakeSupplierCreditsRepository(cache)
              ..shiftResponse = const Left(NetworkFailure());

        final formCubit = SupplierPaymentFormCubit(
          GetPendingPurchaseOrdersTypedUseCase(repo),
          GetFinancialAccountsUseCase(repo),
          GetActiveCashShiftTypedUseCase(repo),
        );

        await formCubit.init(_sampleCredit('1', debt: 500));

        expect(formCubit.state.shiftStatus, CashShiftStatus.error);
        expect(formCubit.state.activeShift, isNull);
        expect(formCubit.state.canSubmit, isFalse);
        expect(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ).hasMatch(formCubit.state.idempotencyKey),
          isTrue,
        );
        await formCubit.close();
      },
    );
  });
}
