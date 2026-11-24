import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_credit_usecase.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit/customer_credit_list_state.dart';

@injectable
class CustomerCreditListCubit extends Cubit<CustomerCreditListState> {
  final GetCreditAccountsUseCase _getCreditAccountsUseCase;
  final ToggleCreditStatusUseCase _toggleCreditStatusUseCase;
  final CreateCreditAccountUseCase _createCreditAccountUseCase;
  final UpdateCreditLimitUseCase _updateCreditLimitUseCase;
  final RegisterCreditPaymentUseCase _registerCreditPaymentUseCase;

  static const String _tag = 'CUSTOMER_CREDIT_LIST_CUBIT';
  int _requestSeq = 0;

  CustomerCreditListCubit(
    this._getCreditAccountsUseCase,
    this._toggleCreditStatusUseCase,
    this._createCreditAccountUseCase,
    this._updateCreditLimitUseCase,
    this._registerCreditPaymentUseCase,
  ) : super(const CustomerCreditListState());

  /// Hidrata inmediatamente en Frame 0 (Zero-Shimmer) desde caché L1 LRU.
  /// Si está fresca, evita llamadas redundantes; si está vencida, revalida SWR.
  void init() {
    final snapshot = _getCreditAccountsUseCase.getLatestSnapshot();
    if (snapshot != null) {
      final res = snapshot.data;
      if (!isClosed) {
        emit(
          state.copyWith(
            status: CustomerCreditsLoadStatus.loaded,
            isLoading: false,
            isRevalidating: snapshot.isStale,
            accounts: res.accounts,
            totalAccounts: res.totalCount,
            totalDebt: res.totalDebt,
            activeAccounts: res.activeAccounts,
            suspendedAccounts: res.suspendedAccounts,
            maxedOutAccounts: res.maxedOutAccounts,
            debtCount: res.debtCount,
            currentPage: snapshot.page,
            pageSize: snapshot.pageSize,
            searchQuery: snapshot.searchQuery,
            withDebtOnly: snapshot.withDebtOnly,
            errorMessage: '',
            clearLoadFailure: true,
            clearTransientError: true,
          ),
        );
      }

      if (snapshot.isStale) {
        loadData(
          page: snapshot.page,
          query: snapshot.searchQuery,
          withDebtOnly: snapshot.withDebtOnly,
          forceRefresh: true,
          silent: true,
        );
      }
      return;
    }

    loadData(page: 1);
  }

  /// Verifica frescura del caché al volver de pantallas hijas; nunca dispara Shimmer.
  Future<void> refreshIfNeeded() async {
    final cached = _getCreditAccountsUseCase.getCached(
      limit: state.pageSize,
      offset: (state.currentPage - 1) * state.pageSize,
      query: state.searchQuery,
      showOnlyWithDebt: state.withDebtOnly,
    );
    if (cached == null || cached.isStale) {
      await loadData(forceRefresh: true, silent: true);
    }
  }

  Future<void> loadData({
    int? page,
    String? query,
    bool? withDebtOnly,
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    final newPage = page ?? state.currentPage;
    final newQuery = (query ?? state.searchQuery).trim();
    final newWithDebtOnly = withDebtOnly ?? state.withDebtOnly;
    final offset = (newPage - 1) * state.pageSize;
    final seq = ++_requestSeq;

    if (!forceRefresh) {
      final cached = _getCreditAccountsUseCase.getCached(
        limit: state.pageSize,
        offset: offset,
        query: newQuery,
        showOnlyWithDebt: newWithDebtOnly,
      );
      if (cached != null) {
        final res = cached.data;
        if (!isClosed) {
          emit(
            state.copyWith(
              status: CustomerCreditsLoadStatus.loaded,
              isLoading: false,
              isRevalidating: cached.isStale && !silent,
              accounts: res.accounts,
              totalAccounts: res.totalCount,
              totalDebt: res.totalDebt,
              activeAccounts: res.activeAccounts,
              suspendedAccounts: res.suspendedAccounts,
              maxedOutAccounts: res.maxedOutAccounts,
              debtCount: res.debtCount,
              currentPage: newPage,
              searchQuery: newQuery,
              withDebtOnly: newWithDebtOnly,
              errorMessage: '',
              clearLoadFailure: true,
              clearTransientError: true,
            ),
          );
        }
        if (!cached.isStale) return;
      }
    }

    final hasVisible = state.accounts.isNotEmpty;
    if (!hasVisible && !silent) {
      if (!isClosed) {
        emit(
          state.copyWith(
            status: CustomerCreditsLoadStatus.loadingCold,
            isLoading: true,
            isRevalidating: false,
            errorMessage: '',
            clearLoadFailure: true,
            clearTransientError: true,
            currentPage: newPage,
            searchQuery: newQuery,
            withDebtOnly: newWithDebtOnly,
          ),
        );
      }
    } else if (!isClosed) {
      emit(
        state.copyWith(
          isRevalidating: true,
          clearTransientError: true,
          currentPage: newPage,
          searchQuery: newQuery,
          withDebtOnly: newWithDebtOnly,
        ),
      );
    }

    final result = await _getCreditAccountsUseCase(
      limit: state.pageSize,
      offset: offset,
      query: newQuery,
      showOnlyWithDebt: newWithDebtOnly,
      forceRefresh: forceRefresh,
    );

    if (isClosed || seq != _requestSeq) return;

    result.fold(
      (failure) {
        LoggerService.w(
          'Error cargando créditos de clientes: ${failure.message}',
          tag: _tag,
        );
        if (state.accounts.isNotEmpty) {
          emit(
            state.copyWith(
              status: CustomerCreditsLoadStatus.errorDegraded,
              isLoading: false,
              isRevalidating: false,
              transientErrorMessage: failure.message,
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: CustomerCreditsLoadStatus.errorCold,
              isLoading: false,
              isRevalidating: false,
              loadFailure: failure,
              errorMessage: failure.message,
            ),
          );
        }
      },
      (res) {
        emit(
          state.copyWith(
            status: CustomerCreditsLoadStatus.loaded,
            isLoading: false,
            isRevalidating: false,
            accounts: res.accounts,
            totalAccounts: res.totalCount,
            totalDebt: res.totalDebt,
            activeAccounts: res.activeAccounts,
            suspendedAccounts: res.suspendedAccounts,
            maxedOutAccounts: res.maxedOutAccounts,
            debtCount: res.debtCount,
            errorMessage: '',
            clearLoadFailure: true,
            clearTransientError: true,
          ),
        );
      },
    );
  }

  void dismissTransientError() {
    if (!isClosed && state.transientErrorMessage != null) {
      emit(
        state.copyWith(
          status: CustomerCreditsLoadStatus.loaded,
          clearTransientError: true,
        ),
      );
    }
  }

  void setPage(int page) {
    if (page >= 1 && page <= state.totalPages && page != state.currentPage) {
      loadData(page: page);
    }
  }

  void setSearch(String query) {
    final trimmed = query.trim();
    if (state.searchQuery != trimmed) {
      loadData(query: trimmed, page: 1);
    }
  }

  void setTab(int index) {
    final nextDebtOnly = index == 1;
    if (state.withDebtOnly != nextDebtOnly) {
      loadData(withDebtOnly: nextDebtOnly, page: 1);
    }
  }

  /// Alterna el estado enviando `!currentIsActive` para revertirlo en PostgreSQL.
  Future<Either<Failure, CustomerCreditEntity>> toggleAccountStatus(
    String creditId,
    bool currentIsActive,
  ) async {
    if (!isClosed) emit(state.copyWith(isMutating: true));

    final result = await _toggleCreditStatusUseCase(creditId, !currentIsActive);
    if (isClosed) return result;

    await result.fold(
      (failure) async {
        emit(
          state.copyWith(
            isMutating: false,
            transientErrorMessage: failure.message,
          ),
        );
      },
      (updated) async {
        final nextAccounts = state.accounts
            .map((a) => a.id == updated.id ? updated : a)
            .toList(growable: false);
        int activeDelta = 0;
        int suspendedDelta = 0;
        if (currentIsActive != updated.isActive) {
          activeDelta = updated.isActive ? 1 : -1;
          suspendedDelta = updated.isActive ? -1 : 1;
        }
        emit(
          state.copyWith(
            isMutating: false,
            accounts: nextAccounts,
            activeAccounts: (state.activeAccounts + activeDelta).clamp(
              0,
              999999,
            ),
            suspendedAccounts: (state.suspendedAccounts + suspendedDelta)
                .clamp(0, 999999),
          ),
        );
        await loadData(forceRefresh: true, silent: true);
      },
    );

    return result;
  }

  Future<Either<Failure, CustomerCreditEntity>> createCreditAccount(
    String customerId,
    double limit,
  ) async {
    if (!isClosed) emit(state.copyWith(isMutating: true));

    final result = await _createCreditAccountUseCase(
      customerId: customerId,
      creditLimit: limit,
    );
    if (isClosed) return result;

    await result.fold(
      (failure) async {
        emit(state.copyWith(isMutating: false));
      },
      (_) async {
        emit(state.copyWith(isMutating: false));
        await loadData(page: 1, forceRefresh: true, silent: true);
      },
    );
    return result;
  }

  Future<Either<Failure, CustomerCreditEntity>> updateCreditLimit(
    String creditId,
    double newLimit,
  ) async {
    if (!isClosed) emit(state.copyWith(isMutating: true));

    final result = await _updateCreditLimitUseCase(
      creditId: creditId,
      newLimit: newLimit,
    );
    if (isClosed) return result;

    await result.fold(
      (failure) async {
        emit(state.copyWith(isMutating: false));
      },
      (_) async {
        emit(state.copyWith(isMutating: false));
        await loadData(forceRefresh: true, silent: true);
      },
    );
    return result;
  }

  Future<void> registerPayment({
    required String customerId,
    required String creditId,
    required double amount,
    String? accountId,
    String? orderId,
    String? notes,
    String? shiftId,
    String? idempotencyKey,
  }) async {
    final result = await _registerCreditPaymentUseCase(
      customerId: customerId,
      creditId: creditId,
      amount: amount,
      accountId: accountId,
      orderId: orderId,
      notes: notes,
      shiftId: shiftId,
      idempotencyKey: idempotencyKey,
    );

    if (isClosed) return;

    await result.fold(
      (failure) async => throw Exception(failure.message),
      (_) async => loadData(forceRefresh: true, silent: true),
    );
  }
}
