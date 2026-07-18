import 'package:injectable/injectable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/fetch_supplier_credits_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/toggle_supplier_credit_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_state.dart';

@injectable
class SupplierCreditsCubit extends Cubit<SupplierCreditsState> {
  final FetchSupplierCreditsUseCase fetchSupplierCreditsUseCase;
  final ToggleSupplierCreditUseCase toggleSupplierCreditUseCase;

  static const int pageSize = 8;

  SupplierCreditsCubit({
    required this.fetchSupplierCreditsUseCase,
    required this.toggleSupplierCreditUseCase,
  }) : super(SupplierCreditsInitial()) {
    loadAccounts();
  }

  Future<void> loadAccounts({
    String? searchQuery,
    bool? withDebtOnly,
    int? page,
    bool refresh = false,
  }) async {
    final currentState = state;
    String currentQuery = '';
    bool currentWithDebt = false;
    int currentPage = 0;
    List<SupplierCreditEntity> currentAccounts = [];
    int currentTotalCount = 0;
    Map<String, dynamic> currentStats = {};

    if (currentState is SupplierCreditsLoaded) {
      currentQuery = searchQuery ?? currentState.searchQuery;
      currentWithDebt = withDebtOnly ?? currentState.withDebtOnly;
      currentPage = page ?? (refresh ? 0 : currentState.currentPage);
      currentAccounts = refresh ? [] : currentState.accounts;
      currentTotalCount = currentState.totalCount;
      currentStats = currentState.stats;
    } else if (currentState is SupplierCreditsLoading) {
      currentQuery = searchQuery ?? currentState.searchQuery;
      currentWithDebt = withDebtOnly ?? currentState.withDebtOnly;
      currentPage = page ?? (refresh ? 0 : currentState.currentPage);
      currentAccounts = refresh ? [] : currentState.currentAccounts;
      currentTotalCount = currentState.totalCount;
      currentStats = currentState.stats;
    } else if (currentState is SupplierCreditsError) {
      currentQuery = searchQuery ?? currentState.searchQuery;
      currentWithDebt = withDebtOnly ?? currentState.withDebtOnly;
      currentPage = page ?? (refresh ? 0 : currentState.currentPage);
      currentAccounts = refresh ? [] : currentState.currentAccounts;
      currentTotalCount = currentState.totalCount;
      currentStats = currentState.stats;
    } else {
      currentQuery = searchQuery ?? '';
      currentWithDebt = withDebtOnly ?? false;
      currentPage = page ?? 0;
    }

    emit(
      SupplierCreditsLoading(
        currentAccounts: currentAccounts,
        searchQuery: currentQuery,
        withDebtOnly: currentWithDebt,
        currentPage: currentPage,
        totalCount: currentTotalCount,
        stats: currentStats,
      ),
    );

    final result = await fetchSupplierCreditsUseCase(
      page: currentPage,
      pageSize: pageSize,
      searchQuery: currentQuery,
      withDebtOnly: currentWithDebt,
    );

    result.fold(
      (failure) {
        String msg = 'Error al cargar cuentas.';
        final errStr = failure.message.toLowerCase();
        if (errStr.contains('socketexception') ||
            errStr.contains('clientexception') ||
            errStr.contains('failed host lookup')) {
          msg = 'Sin conexión a internet.';
        }
        emit(
          SupplierCreditsError(
            message: msg,
            currentAccounts: currentAccounts,
            searchQuery: currentQuery,
            withDebtOnly: currentWithDebt,
            currentPage: currentPage,
            totalCount: currentTotalCount,
            stats: currentStats,
          ),
        );
      },
      (data) {
        emit(
          SupplierCreditsLoaded(
            accounts: data.accounts,
            searchQuery: currentQuery,
            withDebtOnly: currentWithDebt,
            currentPage: currentPage,
            totalCount: data.count,
            stats: data.stats,
          ),
        );
      },
    );
  }

  void setSearchQuery(String query) {
    loadAccounts(searchQuery: query, page: 0, refresh: true);
  }

  void setWithDebtOnly(bool val) {
    loadAccounts(withDebtOnly: val, page: 0, refresh: true);
  }

  void setPage(int page) {
    loadAccounts(page: page);
  }

  Future<void> toggleAccountStatus(SupplierCreditEntity account) async {
    final currentState = state;
    if (currentState is! SupplierCreditsLoaded) return;

    final result = await toggleSupplierCreditUseCase(
      account.creditId,
      account.isActive,
    );

    result.fold(
      (failure) {
        String msg = 'Error al cambiar estado.';
        final errStr = failure.message.toLowerCase();
        if (errStr.contains('socketexception') ||
            errStr.contains('clientexception') ||
            errStr.contains('failed host lookup')) {
          msg = 'Sin conexión a internet.';
        }
        emit(
          SupplierCreditsError(
            message: msg,
            currentAccounts: currentState.accounts,
            searchQuery: currentState.searchQuery,
            withDebtOnly: currentState.withDebtOnly,
            currentPage: currentState.currentPage,
            totalCount: currentState.totalCount,
            stats: currentState.stats,
          ),
        );
      },
      (_) {
        loadAccounts();
      },
    );
  }

  void clearError() {
    final currentState = state;
    if (currentState is SupplierCreditsError) {
      emit(
        SupplierCreditsLoaded(
          accounts: currentState.currentAccounts,
          searchQuery: currentState.searchQuery,
          withDebtOnly: currentState.withDebtOnly,
          currentPage: currentState.currentPage,
          totalCount: currentState.totalCount,
          stats: currentState.stats,
        ),
      );
    }
  }
}
