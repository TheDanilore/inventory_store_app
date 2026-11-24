import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/fetch_supplier_credits_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/register_supplier_payment_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/toggle_supplier_credit_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_state.dart';

@injectable
class SupplierCreditsCubit extends Cubit<SupplierCreditsState> {
  final FetchSupplierCreditsUseCase fetchSupplierCreditsUseCase;
  final ToggleSupplierCreditUseCase toggleSupplierCreditUseCase;
  final RegisterSupplierPaymentUseCase registerSupplierPaymentUseCase;

  static const int pageSize = SupplierCreditsState.defaultPageSize;

  int _loadRequestId = 0;

  SupplierCreditsCubit({
    required this.fetchSupplierCreditsUseCase,
    required this.toggleSupplierCreditUseCase,
    required this.registerSupplierPaymentUseCase,
  }) : super(_buildInitialState(fetchSupplierCreditsUseCase)) {
    if (state.status == SupplierCreditsLoadStatus.coldLoading) {
      loadAccounts();
    } else if (state.isRevalidating) {
      loadAccounts(forceRefresh: true, silent: true);
    }
  }

  static SupplierCreditsState _buildInitialState(
    FetchSupplierCreditsUseCase fetchUseCase,
  ) {
    final snapshot = fetchUseCase.getLatestSnapshot();
    if (snapshot != null) {
      return SupplierCreditsState(
        status: SupplierCreditsLoadStatus.loaded,
        accounts: snapshot.data.accounts,
        stats: snapshot.data.stats ?? const SupplierCreditStatsEntity.empty(),
        searchQuery: snapshot.searchQuery,
        withDebtOnly: snapshot.withDebtOnly,
        currentPage: snapshot.page,
        pageSize: snapshot.pageSize,
        totalCount: snapshot.data.totalCount,
        isFromCache: true,
        isRevalidating: snapshot.isStale,
      );
    }
    return const SupplierCreditsState(
      status: SupplierCreditsLoadStatus.coldLoading,
    );
  }

  String formatFailureMessage(Failure failure, {required String fallback}) {
    return switch (failure) {
      NetworkFailure() => failure.message,
      UnauthorizedFailure() => failure.message,
      ValidationFailure() => failure.message,
      NotFoundFailure() => failure.message,
      ServerFailure() =>
        failure.message.isNotEmpty ? failure.message : fallback,
      CacheFailure() => failure.message,
      StockFailure() => failure.message,
      UnexpectedFailure() => fallback,
    };
  }

  Future<void> loadAccounts({
    String? searchQuery,
    bool? withDebtOnly,
    int? page,
    bool forceRefresh = false,
    bool silent = false,
  }) async {
    final nextQuery = (searchQuery ?? state.searchQuery).trim();
    final nextWithDebt = withDebtOnly ?? state.withDebtOnly;
    final nextPage = page ?? state.currentPage;

    // 1. Consulta L1 en memoria si no se forzó refresh
    if (!forceRefresh) {
      final cached = fetchSupplierCreditsUseCase.getCachedPage(
        page: nextPage,
        pageSize: state.pageSize,
        searchQuery: nextQuery,
        withDebtOnly: nextWithDebt,
      );

      if (cached != null) {
        emit(
          state.copyWith(
            status: SupplierCreditsLoadStatus.loaded,
            accounts: cached.data.accounts,
            stats: cached.data.stats ?? state.stats,
            searchQuery: nextQuery,
            withDebtOnly: nextWithDebt,
            currentPage: nextPage,
            totalCount: cached.data.totalCount,
            isFromCache: true,
            isRevalidating: cached.isStale,
            clearLoadFailure: true,
          ),
        );

        if (!cached.isStale) {
          return;
        }
        // Si está stale, continúa debajo en background (SWR) sin mostrar Shimmer
        silent = true;
      }
    }

    final requestId = ++_loadRequestId;
    final hasVisibleData = state.accounts.isNotEmpty;

    emit(
      state.copyWith(
        status:
            hasVisibleData
                ? SupplierCreditsLoadStatus.loaded
                : SupplierCreditsLoadStatus.coldLoading,
        searchQuery: nextQuery,
        withDebtOnly: nextWithDebt,
        currentPage: nextPage,
        isRevalidating: hasVisibleData || silent,
        clearLoadFailure: true,
      ),
    );

    final result = await fetchSupplierCreditsUseCase(
      page: nextPage,
      pageSize: state.pageSize,
      searchQuery: nextQuery,
      withDebtOnly: nextWithDebt,
      forceRefresh: forceRefresh,
    );

    if (isClosed || requestId != _loadRequestId) return;

    result.fold(
      (failure) {
        if (state.accounts.isNotEmpty) {
          // Modo degradado: conserva los datos cacheados visibles
          emit(
            state.copyWith(
              status: SupplierCreditsLoadStatus.loaded,
              isRevalidating: false,
              loadFailure: failure,
            ),
          );
        } else {
          emit(
            state.copyWith(
              status: SupplierCreditsLoadStatus.error,
              isRevalidating: false,
              loadFailure: failure,
            ),
          );
        }
      },
      (data) {
        emit(
          state.copyWith(
            status: SupplierCreditsLoadStatus.loaded,
            accounts: data.accounts,
            stats: data.stats ?? state.stats,
            searchQuery: nextQuery,
            withDebtOnly: nextWithDebt,
            currentPage: nextPage,
            totalCount: data.totalCount,
            isRevalidating: false,
            isFromCache: false,
            clearLoadFailure: true,
          ),
        );
      },
    );
  }

  void setSearchQuery(String query) {
    final trimmed = query.trim();
    if (trimmed == state.searchQuery &&
        state.status == SupplierCreditsLoadStatus.loaded &&
        !state.isRevalidating) {
      return;
    }
    loadAccounts(searchQuery: trimmed, page: 0);
  }

  void setWithDebtOnly(bool val) {
    if (val == state.withDebtOnly &&
        state.status == SupplierCreditsLoadStatus.loaded) {
      return;
    }
    loadAccounts(withDebtOnly: val, page: 0);
  }

  void setPage(int page) {
    if (page < 0 || page == state.currentPage) return;
    loadAccounts(page: page);
  }

  void clearFilters() {
    loadAccounts(searchQuery: '', withDebtOnly: false, page: 0);
  }

  Future<void> toggleAccountStatus(SupplierCreditEntity account) async {
    if (state.mutationStatus == SupplierCreditMutationStatus.submitting) return;

    emit(
      state.copyWith(
        mutationStatus: SupplierCreditMutationStatus.submitting,
        clearMutationMessage: true,
        clearMutationFailure: true,
      ),
    );

    final result = await toggleSupplierCreditUseCase(
      account.creditId,
      account.isActive,
    );

    if (isClosed) return;

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            mutationStatus: SupplierCreditMutationStatus.failure,
            mutationMessage: formatFailureMessage(
              failure,
              fallback: 'Error al cambiar estado del crédito.',
            ),
            mutationFailure: failure,
          ),
        );
      },
      (updatedFromServer) {
        final patched =
            updatedFromServer ??
            account.copyWith(isActive: !account.isActive);
        final updatedAccounts = _replaceAccountInList(state.accounts, patched);
        final successMsg =
            patched.isActive ? 'Crédito reactivado.' : 'Crédito suspendido.';

        emit(
          state.copyWith(
            accounts: updatedAccounts,
            mutationStatus: SupplierCreditMutationStatus.success,
            mutationMessage: successMsg,
            clearMutationFailure: true,
          ),
        );

        loadAccounts(forceRefresh: true, silent: true);
      },
    );
  }

  Future<void> registerPayment(RegisterSupplierPaymentParams params) async {
    if (state.mutationStatus == SupplierCreditMutationStatus.submitting) return;

    emit(
      state.copyWith(
        mutationStatus: SupplierCreditMutationStatus.submitting,
        clearMutationMessage: true,
        clearMutationFailure: true,
      ),
    );

    final result = await registerSupplierPaymentUseCase(params);

    if (isClosed) return;

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            mutationStatus: SupplierCreditMutationStatus.failure,
            mutationMessage: formatFailureMessage(
              failure,
              fallback: 'Error al registrar el pago.',
            ),
            mutationFailure: failure,
          ),
        );
      },
      (updatedFromServer) {
        var updatedAccounts = state.accounts;
        if (updatedFromServer != null) {
          updatedAccounts = _replaceAccountInList(
            state.accounts,
            updatedFromServer,
          );
        } else {
          final index = state.accounts.indexWhere(
            (s) => s.creditId == params.creditId,
          );
          if (index >= 0) {
            final old = state.accounts[index];
            final newDebt = (old.currentDebt - params.amount).clamp(
              0.0,
              double.infinity,
            );
            updatedAccounts = _replaceAccountInList(
              state.accounts,
              old.copyWith(currentDebt: newDebt),
            );
          }
        }

        emit(
          state.copyWith(
            accounts: updatedAccounts,
            mutationStatus: SupplierCreditMutationStatus.success,
            mutationMessage:
                'Pago de S/ ${params.amount.toStringAsFixed(2)} registrado exitosamente.',
            clearMutationFailure: true,
          ),
        );

        // Revalidación silenciosa para sincronizar KPIs y filtros sin Shimmer
        loadAccounts(forceRefresh: true, silent: true);
      },
    );
  }

  void onAccountSaved(SupplierCreditEntity? updatedAccount) {
    if (updatedAccount != null) {
      final updatedAccounts = _replaceAccountInList(
        state.accounts,
        updatedAccount,
      );
      emit(state.copyWith(accounts: updatedAccounts));
    }
    loadAccounts(forceRefresh: true, silent: true);
  }

  List<SupplierCreditEntity> _replaceAccountInList(
    List<SupplierCreditEntity> source,
    SupplierCreditEntity updated,
  ) {
    final idx = source.indexWhere((a) => a.creditId == updated.creditId);
    if (idx == -1) return source;
    final next = List<SupplierCreditEntity>.from(source);
    next[idx] = updated;
    return List.unmodifiable(next);
  }

  void clearLoadFailure() {
    if (state.loadFailure != null) {
      emit(state.copyWith(clearLoadFailure: true));
    }
  }

  void clearMutationFeedback() {
    if (state.mutationStatus != SupplierCreditMutationStatus.idle ||
        state.mutationMessage != null ||
        state.mutationFailure != null) {
      emit(
        state.copyWith(
          mutationStatus: SupplierCreditMutationStatus.idle,
          clearMutationMessage: true,
          clearMutationFailure: true,
        ),
      );
    }
  }
}
