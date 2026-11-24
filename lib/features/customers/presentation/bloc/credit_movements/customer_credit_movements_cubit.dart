import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/customers/data/cache/credit_movements_cache.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/customer_credits_repository.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/credit_movements/customer_credit_movements_state.dart';

@injectable
class CustomerCreditMovementsCubit extends Cubit<CustomerCreditMovementsState> {
  final CustomerCreditsRepository _repository;
  final CreditMovementsCache _cache = CreditMovementsCache();

  static const String _tag = 'CUSTOMER_CREDIT_MOVEMENTS_CUBIT';

  CustomerCreditMovementsCubit(this._repository)
    : super(
        const CustomerCreditMovementsState(
          creditId: '',
          customerName: '',
          currentDebt: 0.0,
          creditLimit: 0.0,
        ),
      );

  void init({
    required String creditId,
    required String customerName,
    required double currentDebt,
    required double creditLimit,
    String customerId = '',
  }) {
    final cached = _cache.get(
      creditId: creditId,
      dateFilter: state.dateFilter,
      typeFilter: state.typeFilter,
      page: state.currentPage,
    );

    if (cached != null) {
      if (!isClosed) {
        emit(
          state.copyWith(
            creditId: creditId,
            customerId: customerId,
            customerName: customerName,
            currentDebt: cached.currentDebt ?? currentDebt,
            creditLimit: cached.creditLimit ?? creditLimit,
            movements: cached.items,
            totalCount: cached.totalCount,
            totalCharged: cached.totalCharged,
            totalPaid: cached.totalPaid,
            chargeCount: cached.chargeCount,
            paymentCount: cached.paymentCount,
            isLoading: false,
            isRevalidating: true,
            error: null,
          ),
        );
      }
    } else if (!isClosed) {
      emit(
        state.copyWith(
          creditId: creditId,
          customerId: customerId,
          customerName: customerName,
          currentDebt: currentDebt,
          creditLimit: creditLimit,
          isLoading: true,
          isRevalidating: false,
        ),
      );
    }

    loadData(forceRefresh: false);
  }

  Future<void> loadData({
    bool forceRefresh = false,
    bool fetchOnlyMovements = false,
  }) async {
    if (!isClosed) {
      if (state.movements.isEmpty) {
        emit(state.copyWith(isLoading: true, error: null));
      } else {
        emit(state.copyWith(isRevalidating: true, error: null));
      }
    }

    final dateFilterParam = state.dateFilter == 'all' ? null : state.dateFilter;
    final movementTypeParam = state.typeFilter == 'ALL' ? null : state.typeFilter;

    final movementsFuture = _repository.getCreditMovements(
      creditId: state.creditId,
      limit: state.pageSize,
      offset: state.currentPage * state.pageSize,
      dateFilter: dateFilterParam,
      movementType: movementTypeParam,
    );

    final Future<
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
    totalsFuture =
        fetchOnlyMovements
            ? Future.value(
              Right((
                totalCharged: state.totalCharged,
                totalPaid: state.totalPaid,
                chargeCount: state.chargeCount,
                paymentCount: state.paymentCount,
              )),
            )
            : _repository.getCreditMovementsTotals(
              creditId: state.creditId,
              dateFilter: dateFilterParam,
            );

    final Future<Either<Failure, CustomerCreditEntity?>> accountFuture =
        (!fetchOnlyMovements && state.customerId.isNotEmpty)
            ? _repository.getCreditAccountByCustomer(state.customerId)
            : Future.value(const Right(null));

    final (movementsEither, totalsEither, accountEither) =
        await (movementsFuture, totalsFuture, accountFuture).wait;

    if (isClosed) return;

    final totalResult = totalsEither.fold(
      (failure) {
        LoggerService.w(
          'Error obteniendo totales de movimientos: ${failure.message}',
          tag: _tag,
        );
        return (
          totalCharged: state.totalCharged,
          totalPaid: state.totalPaid,
          chargeCount: state.chargeCount,
          paymentCount: state.paymentCount,
        );
      },
      identity,
    );

    final updatedAccount = accountEither.fold<CustomerCreditEntity?>(
      (_) => null,
      identity,
    );

    movementsEither.fold(
      (failure) {
        LoggerService.e(
          'Error cargando movimientos para creditId ${state.creditId}: ${failure.message}',
          tag: _tag,
        );
        emit(
          state.copyWith(
            isLoading: false,
            isRevalidating: false,
            error: state.movements.isEmpty ? failure.message : null,
          ),
        );
      },
      (movementsResult) {
        final items = movementsResult.items;
        final newCurrentDebt =
            updatedAccount?.currentDebt ?? state.currentDebt;
        final newCreditLimit =
            updatedAccount?.creditLimit ?? state.creditLimit;

        _cache.put(
          creditId: state.creditId,
          dateFilter: state.dateFilter,
          typeFilter: state.typeFilter,
          page: state.currentPage,
          entry: CreditMovementsCacheEntry(
            items: items,
            totalCount: movementsResult.totalCount,
            totalCharged: totalResult.totalCharged,
            totalPaid: totalResult.totalPaid,
            chargeCount: totalResult.chargeCount,
            paymentCount: totalResult.paymentCount,
            currentDebt: newCurrentDebt,
            creditLimit: newCreditLimit,
          ),
        );

        emit(
          state.copyWith(
            isLoading: false,
            isRevalidating: false,
            movements: items,
            totalCount: movementsResult.totalCount,
            totalCharged: totalResult.totalCharged,
            totalPaid: totalResult.totalPaid,
            chargeCount: totalResult.chargeCount,
            paymentCount: totalResult.paymentCount,
            currentDebt: newCurrentDebt,
            creditLimit: newCreditLimit,
          ),
        );
      },
    );
  }

  Future<void> registerPayment({
    required double amount,
    String? accountId,
    String? orderId,
    String? notes,
    String? shiftId,
    String? idempotencyKey,
  }) async {
    final result = await _repository.registerPayment(
      customerId: state.customerId,
      creditId: state.creditId,
      amount: amount,
      accountId: accountId,
      orderId: orderId,
      notes: notes,
      shiftId: shiftId,
      idempotencyKey: idempotencyKey,
    );

    if (isClosed) return;

    await result.fold(
      (failure) async {
        LoggerService.e(
          'Error al registrar abono en CustomerCreditMovementsCubit: ${failure.message}',
          tag: _tag,
        );
        throw Exception(failure.message);
      },
      (_) async {
        _cache.invalidate(state.creditId);
        await loadData(forceRefresh: true);
      },
    );
  }

  Future<void> setPage(int page) async {
    if (page == state.currentPage) return;

    final cached = _cache.get(
      creditId: state.creditId,
      dateFilter: state.dateFilter,
      typeFilter: state.typeFilter,
      page: page,
    );

    if (cached != null) {
      if (!isClosed) {
        emit(
          state.copyWith(
            currentPage: page,
            movements: cached.items,
            totalCount: cached.totalCount,
            isLoading: false,
            isRevalidating: true,
          ),
        );
      }
    } else if (!isClosed) {
      emit(state.copyWith(currentPage: page, isLoading: true));
    }

    await loadData(fetchOnlyMovements: true);
  }

  Future<void> setDateFilter(String filter) async {
    if (filter == state.dateFilter) return;
    if (!isClosed) emit(state.copyWith(dateFilter: filter, currentPage: 0));
    await loadData();
  }

  Future<void> setTypeFilter(String filter) async {
    if (filter == state.typeFilter) return;
    if (!isClosed) emit(state.copyWith(typeFilter: filter, currentPage: 0));
    await loadData();
  }
}
