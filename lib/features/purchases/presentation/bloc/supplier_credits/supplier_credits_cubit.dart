import 'package:injectable/injectable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/fetch_supplier_credits_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/toggle_supplier_credit_usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/usecases/register_supplier_payment_usecase.dart';
import 'package:inventory_store_app/features/purchases/presentation/bloc/supplier_credits/supplier_credits_state.dart';

@injectable
class SupplierCreditsCubit extends Cubit<SupplierCreditsState> {
  final FetchSupplierCreditsUseCase fetchSupplierCreditsUseCase;
  final ToggleSupplierCreditUseCase toggleSupplierCreditUseCase;
  final RegisterSupplierPaymentUseCase registerSupplierPaymentUseCase;

  static const int pageSize = 8;

  SupplierCreditsCubit({
    required this.fetchSupplierCreditsUseCase,
    required this.toggleSupplierCreditUseCase,
    required this.registerSupplierPaymentUseCase,
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

  Future<void> registerPayment(RegisterSupplierPaymentParams params) async {
    final currentState = state;
    List<SupplierCreditEntity> currentList = [];
    String query = '';
    bool withDebt = false;
    int page = 0;
    int count = 0;
    Map<String, dynamic> stats = {};

    if (currentState is SupplierCreditsLoaded) {
      currentList = currentState.accounts;
      query = currentState.searchQuery;
      withDebt = currentState.withDebtOnly;
      page = currentState.currentPage;
      count = currentState.totalCount;
      stats = currentState.stats;
    } else if (currentState is SupplierCreditsError) {
      currentList = currentState.currentAccounts;
      query = currentState.searchQuery;
      withDebt = currentState.withDebtOnly;
      page = currentState.currentPage;
      count = currentState.totalCount;
      stats = currentState.stats;
    } else if (currentState is SupplierCreditSaveError) {
      currentList = currentState.currentAccounts;
      query = currentState.searchQuery;
      withDebt = currentState.withDebtOnly;
      page = currentState.currentPage;
      count = currentState.totalCount;
      stats = currentState.stats;
    } else {
      return;
    }

    emit(SupplierCreditSaving(
      currentAccounts: currentList,
      searchQuery: query,
      withDebtOnly: withDebt,
      currentPage: page,
      totalCount: count,
      stats: stats,
    ));

    final result = await registerSupplierPaymentUseCase(params);

    result.fold(
      (failure) {
        emit(SupplierCreditSaveError(
          currentAccounts: currentList,
          searchQuery: query,
          withDebtOnly: withDebt,
          currentPage: page,
          totalCount: count,
          stats: stats,
          message: failure.message,
        ));
      },
      (_) {
        List<SupplierCreditEntity> updatedList = List.from(currentList);
        final index = updatedList.indexWhere((s) => s.creditId == params.creditId);
        
        if (index >= 0) {
          final old = updatedList[index];
          final newDebt = (old.currentDebt - params.amount).clamp(0.0, double.infinity);
          updatedList[index] = old.copyWith(currentDebt: newDebt);
        }

        emit(SupplierCreditSaveSuccess(
          currentAccounts: updatedList,
          searchQuery: query,
          withDebtOnly: withDebt,
          currentPage: page,
          totalCount: count,
          stats: stats,
          message: 'Pago de S/ ${params.amount.toStringAsFixed(2)} registrado exitosamente.',
        ));

        emit(SupplierCreditsLoaded(
          accounts: updatedList,
          searchQuery: query,
          withDebtOnly: withDebt,
          currentPage: page,
          totalCount: count,
          stats: stats,
        ));
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
