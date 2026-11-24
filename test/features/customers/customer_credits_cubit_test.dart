import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/customers/data/cache/customer_credits_lru_cache.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_list_result_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/customer_credits_repository.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_credit_usecase.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credit_list_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credit_list_state.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/register_payment/register_payment_cubit.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/register_payment/register_payment_state.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/financial_accounts_repository.dart';
import 'package:inventory_store_app/features/financial/domain/usecases/get_financial_accounts_usecase.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/get_pending_customer_orders_uc.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';
import 'package:inventory_store_app/features/pos/domain/repositories/cash_shift_repository.dart';
import 'package:inventory_store_app/features/pos/domain/usecases/check_active_shift_uc.dart';

class _FakeCustomerCreditsRepository implements CustomerCreditsRepository {
  final CustomerCreditsLruCache cache;

  _FakeCustomerCreditsRepository(this.cache);

  int fetchCalls = 0;
  bool? lastToggleValueSent;

  Future<Either<Failure, CustomerCreditListResultEntity>> Function({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt,
    bool forceRefresh,
  })?
  onGetAccounts;

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
    return cache.getPage(key);
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
  getLatestCachedSnapshot() => cache.getLatestSnapshot();

  @override
  void invalidateCache() => cache.invalidateAll();

  @override
  Future<Either<Failure, CustomerCreditListResultEntity>> getCreditAccounts({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
    bool forceRefresh = false,
  }) async {
    fetchCalls++;
    if (onGetAccounts != null) {
      final res = await onGetAccounts!(
        limit: limit,
        offset: offset,
        query: query,
        showOnlyWithDebt: showOnlyWithDebt,
        forceRefresh: forceRefresh,
      );
      res.fold((_) {}, (data) {
        final page = limit > 0 ? (offset ~/ limit) + 1 : 1;
        final key = CustomerCreditsLruCache.buildKey(
          page: page,
          pageSize: limit,
          searchQuery: query ?? '',
          withDebtOnly: showOnlyWithDebt,
        );
        cache.putPage(
          key: key,
          data: data,
          searchQuery: query ?? '',
          withDebtOnly: showOnlyWithDebt,
          page: page,
          pageSize: limit,
        );
      });
      return res;
    }
    return const Right(
      CustomerCreditListResultEntity(
        accounts: [],
        totalCount: 0,
        totalDebt: 0,
        activeAccounts: 0,
        suspendedAccounts: 0,
        maxedOutAccounts: 0,
        debtCount: 0,
      ),
    );
  }

  @override
  Future<Either<Failure, CustomerCreditEntity>> toggleCreditStatus(
    String creditId,
    bool isActive,
  ) async {
    lastToggleValueSent = isActive;
    final updated = CustomerCreditEntity(
      id: creditId,
      customerRecordId: 'cust_1',
      profileId: null,
      customerName: 'Cliente ERP',
      creditLimit: 500,
      currentDebt: 100,
      isActive: isActive,
    );
    cache.patchAccount(updated);
    return Right(updated);
  }

  @override
  Future<Either<Failure, CustomerCreditEntity>> createCreditAccount({
    required String customerId,
    required double creditLimit,
  }) async => Right(
    CustomerCreditEntity(
      id: 'cr_new',
      customerRecordId: customerId,
      creditLimit: creditLimit,
      isActive: true,
    ),
  );

  @override
  Future<Either<Failure, CustomerCreditEntity?>> getCreditAccountByCustomer(
    String customerId,
  ) async => const Right(null);

  @override
  Future<Either<Failure, ({List<CreditMovementEntity> items, int totalCount})>>
  getCreditMovements({
    required String creditId,
    required int limit,
    required int offset,
    String? dateFilter,
    String? movementType,
  }) async => const Right((items: [], totalCount: 0));

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
  }) async => const Right((
    totalCharged: 0.0,
    totalPaid: 0.0,
    chargeCount: 0,
    paymentCount: 0,
  ));

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
    cache.invalidateAll();
    return const Right(null);
  }

  @override
  Future<Either<Failure, List<CustomerEntity>>> searchCustomersWithoutCredit(
    String query, {
    int limit = 8,
  }) async => const Right([]);

  @override
  Future<Either<Failure, CustomerCreditEntity>> updateCreditLimit({
    required String creditId,
    required double newLimit,
  }) async => Right(
    CustomerCreditEntity(
      id: creditId,
      customerRecordId: 'cust_1',
      creditLimit: newLimit,
      isActive: true,
    ),
  );
}

class _FakeOrdersRepo implements OrdersRepository {
  @override
  Future<Either<Failure, List<OrderEntity>>> getPendingOrdersByCustomer(
    String customerId,
  ) async => const Right([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAccountsRepo implements FinancialAccountsRepository {
  final List<FinancialAccountEntity> accounts;
  _FakeAccountsRepo(this.accounts);

  @override
  Future<List<FinancialAccountEntity>> getAccounts({
    required int page,
    required int pageSize,
    bool force = false,
  }) async => accounts;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCashShiftRepo implements CashShiftRepository {
  Either<Failure, CashShiftEntity?> nextResult = Right(
    CashShiftEntity(
      id: 'shift_1',
      accountId: 'acc_caja',
      status: CashShiftStatus.open,
      openedAt: DateTime(2026),
      openingAmount: 100,
    ),
  );

  @override
  Future<Either<Failure, CashShiftEntity?>> checkActiveShift(
    String accountId,
  ) async => nextResult;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CustomerCreditEntity _sampleAccount(
  String id,
  String name, {
  String? profileId,
  double debt = 120,
  bool isActive = true,
}) {
  return CustomerCreditEntity(
    id: id,
    profileId: profileId,
    customerRecordId: 'cust_$id',
    customerName: name,
    creditLimit: 1000,
    currentDebt: debt,
    isActive: isActive,
  );
}

void main() {
  group('CustomerCreditsLruCache', () {
    test('evicts oldest entry beyond maxPages (15)', () {
      final cache = CustomerCreditsLruCache();
      for (int i = 0; i < 18; i++) {
        final key = CustomerCreditsLruCache.buildKey(
          page: 1,
          pageSize: 15,
          searchQuery: 'q$i',
          withDebtOnly: false,
        );
        cache.putPage(
          key: key,
          data: CustomerCreditListResultEntity(
            accounts: [_sampleAccount('a$i', 'Cliente $i')],
            totalCount: 1,
            totalDebt: 120,
            activeAccounts: 1,
            suspendedAccounts: 0,
            maxedOutAccounts: 0,
            debtCount: 1,
          ),
          searchQuery: 'q$i',
          withDebtOnly: false,
          page: 1,
          pageSize: 15,
        );
      }

      expect(
        cache.getPage(
          CustomerCreditsLruCache.buildKey(
            page: 1,
            pageSize: 15,
            searchQuery: 'q0',
            withDebtOnly: false,
          ),
        ),
        isNull,
      );
      expect(
        cache.getPage(
          CustomerCreditsLruCache.buildKey(
            page: 1,
            pageSize: 15,
            searchQuery: 'q3',
            withDebtOnly: false,
          ),
        ),
        isNotNull,
      );
    });
  });

  group('CustomerCreditListCubit', () {
    late CustomerCreditsLruCache cache;
    late _FakeCustomerCreditsRepository repo;
    late CustomerCreditListCubit cubit;

    setUp(() {
      cache = CustomerCreditsLruCache();
      repo = _FakeCustomerCreditsRepository(cache);
      cubit = CustomerCreditListCubit(
        GetCreditAccountsUseCase(repo),
        ToggleCreditStatusUseCase(repo),
        CreateCreditAccountUseCase(repo),
        UpdateCreditLimitUseCase(repo),
        RegisterCreditPaymentUseCase(repo),
      );
    });

    tearDown(() async {
      await cubit.close();
    });

    test('init hydrates Frame 0 from cache without Shimmer or network call when fresh', () async {
      final key = CustomerCreditsLruCache.buildKey(
        page: 1,
        pageSize: 15,
        searchQuery: '',
        withDebtOnly: false,
      );
      cache.putPage(
        key: key,
        data: CustomerCreditListResultEntity(
          accounts: [_sampleAccount('1', 'Empresa Sin Profile', profileId: null)],
          totalCount: 1,
          totalDebt: 120,
          activeAccounts: 1,
          suspendedAccounts: 0,
          maxedOutAccounts: 0,
          debtCount: 1,
        ),
        searchQuery: '',
        withDebtOnly: false,
        page: 1,
        pageSize: 15,
      );

      final states = <CustomerCreditListState>[];
      final sub = cubit.stream.listen(states.add);

      cubit.init();
      await Future<void>.delayed(Duration.zero);

      expect(
        states.any((s) => s.status == CustomerCreditsLoadStatus.loadingCold),
        isFalse,
      );
      expect(repo.fetchCalls, 0);
      expect(cubit.state.status, CustomerCreditsLoadStatus.loaded);
      expect(cubit.state.accounts.single.customerName, 'Empresa Sin Profile');
      expect(cubit.state.accounts.single.profileId, isNull);
      expect(cubit.state.accounts.single.effectiveCustomerId, 'cust_1');

      await sub.cancel();
    });

    test('preserves cached data in errorDegraded on forceRefresh failure; uses errorCold when empty', () async {
      repo.onGetAccounts = ({
        required limit,
        required offset,
        query,
        showOnlyWithDebt = false,
        forceRefresh = false,
      }) async => const Left(NetworkFailure());

      await cubit.loadData(page: 1);
      expect(cubit.state.status, CustomerCreditsLoadStatus.errorCold);
      expect(cubit.state.accounts, isEmpty);

      // Ahora con caché visible
      final key = CustomerCreditsLruCache.buildKey(
        page: 1,
        pageSize: 15,
        searchQuery: '',
        withDebtOnly: false,
      );
      cache.putPage(
        key: key,
        data: CustomerCreditListResultEntity(
          accounts: [_sampleAccount('2', 'Rosa Perez')],
          totalCount: 1,
          totalDebt: 120,
          activeAccounts: 1,
          suspendedAccounts: 0,
          maxedOutAccounts: 0,
          debtCount: 1,
        ),
        searchQuery: '',
        withDebtOnly: false,
        page: 1,
        pageSize: 15,
      );
      cubit.init();
      expect(cubit.state.status, CustomerCreditsLoadStatus.loaded);

      await cubit.loadData(forceRefresh: true, silent: true);
      expect(cubit.state.status, CustomerCreditsLoadStatus.errorDegraded);
      expect(cubit.state.accounts.single.customerName, 'Rosa Perez');
      expect(cubit.state.transientErrorMessage, isNotNull);
    });

    test('sequence guard discards stale slower search response', () async {
      final slowCompleter =
          Completer<Either<Failure, CustomerCreditListResultEntity>>();
      final fastCompleter =
          Completer<Either<Failure, CustomerCreditListResultEntity>>();

      repo.onGetAccounts = ({
        required limit,
        required offset,
        query,
        showOnlyWithDebt = false,
        forceRefresh = false,
      }) {
        if (query == 'lento') return slowCompleter.future;
        return fastCompleter.future;
      };

      final slowFuture = cubit.loadData(page: 1, query: 'lento');
      final fastFuture = cubit.loadData(page: 1, query: 'rapido');

      fastCompleter.complete(
        Right(
          CustomerCreditListResultEntity(
            accounts: [_sampleAccount('f1', 'Cliente Rápido')],
            totalCount: 1,
            totalDebt: 50,
            activeAccounts: 1,
            suspendedAccounts: 0,
            maxedOutAccounts: 0,
            debtCount: 1,
          ),
        ),
      );
      await fastFuture;

      slowCompleter.complete(
        Right(
          CustomerCreditListResultEntity(
            accounts: [_sampleAccount('s1', 'Cliente Lento Obsoleto')],
            totalCount: 1,
            totalDebt: 90,
            activeAccounts: 1,
            suspendedAccounts: 0,
            maxedOutAccounts: 0,
            debtCount: 1,
          ),
        ),
      );
      await slowFuture;

      expect(cubit.state.searchQuery, 'rapido');
      expect(cubit.state.accounts.single.customerName, 'Cliente Rápido');
    });

    test('toggleAccountStatus sends negated !currentIsActive to repository', () async {
      repo.onGetAccounts = ({
        required limit,
        required offset,
        query,
        showOnlyWithDebt = false,
        forceRefresh = false,
      }) async => Right(
        CustomerCreditListResultEntity(
          accounts: [_sampleAccount('cr_1', 'Cliente Test', isActive: true)],
          totalCount: 1,
          totalDebt: 120,
          activeAccounts: 1,
          suspendedAccounts: 0,
          maxedOutAccounts: 0,
          debtCount: 1,
        ),
      );

      await cubit.loadData(page: 1);
      final res = await cubit.toggleAccountStatus('cr_1', true);

      expect(repo.lastToggleValueSent, isFalse);
      expect(res.isRight(), isTrue);
    });
  });

  group('RegisterPaymentCubit ACID Shift & Idempotency', () {
    test('clears previous activeShift on checkActiveShift failure and preserves UUID v4 key', () async {
      final caja = FinancialAccountEntity(
        id: 'acc_caja',
        name: 'Caja Principal',
        type: 'CAJA',
        balance: 500,
        isActive: true,
        createdAt: DateTime(2026),
      );
      final shiftRepo = _FakeCashShiftRepo();
      final paymentCubit = RegisterPaymentCubit(
        GetFinancialAccountsUseCase(_FakeAccountsRepo([caja])),
        GetPendingCustomerOrdersUc(_FakeOrdersRepo()),
        CheckActiveShiftUc(shiftRepo),
      );

      await paymentCubit.loadInitialData('cust_1');
      expect(paymentCubit.state.shiftStatus, CustomerPaymentShiftStatus.open);
      expect(paymentCubit.state.activeShift, isNotNull);
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ).hasMatch(paymentCubit.state.idempotencyKey),
        isTrue,
      );

      // Falla posterior al validar turno: activeShift debe quedar null
      shiftRepo.nextResult = const Left(NetworkFailure());
      await paymentCubit.checkActiveShift('acc_caja');

      expect(paymentCubit.state.shiftStatus, CustomerPaymentShiftStatus.error);
      expect(paymentCubit.state.activeShift, isNull);
      expect(paymentCubit.state.shiftErrorMessage, isNotNull);

      await paymentCubit.close();
    });
  });
}
