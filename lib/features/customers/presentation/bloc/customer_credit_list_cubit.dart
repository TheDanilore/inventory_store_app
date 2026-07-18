import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/customer_credit_ucs.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_credit_list_state.dart';

@injectable
class CustomerCreditListCubit extends Cubit<CustomerCreditListState> {
  final GetCreditAccountsUseCase _getCreditAccountsUseCase;
  final ToggleCreditStatusUseCase _toggleCreditStatusUseCase;
  final CreateCreditAccountUseCase _createCreditAccountUseCase;
  final RegisterCreditPaymentUseCase _registerCreditPaymentUseCase;

  CustomerCreditListCubit(
    this._getCreditAccountsUseCase,
    this._toggleCreditStatusUseCase,
    this._createCreditAccountUseCase,
    this._registerCreditPaymentUseCase,
  ) : super(const CustomerCreditListState());

  void init() {
    loadData(page: 1);
  }

  Future<void> loadData({int? page, String? query, bool? withDebtOnly}) async {
    final newPage = page ?? state.currentPage;
    final newQuery = query ?? state.searchQuery;
    final newWithDebtOnly = withDebtOnly ?? state.withDebtOnly;

    emit(state.copyWith(
      isLoading: true,
      errorMessage: '',
      currentPage: newPage,
      searchQuery: newQuery,
      withDebtOnly: newWithDebtOnly,
    ));

    try {
      final offset = (newPage - 1) * state.pageSize;
      
      final result = await _getCreditAccountsUseCase(
        limit: state.pageSize,
        offset: offset,
        query: newQuery,
        showOnlyWithDebt: newWithDebtOnly,
      );

      emit(state.copyWith(
        isLoading: false,
        accounts: result.accounts,
        totalAccounts: result.totalCount,
        totalDebt: result.totalDebt,
        activeAccounts: result.activeAccounts,
        suspendedAccounts: result.suspendedAccounts,
        maxedOutAccounts: result.maxedOutAccounts,
      ));
    } catch (e) {
      String errorMessage = 'Error al cargar los créditos.';
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        errorMessage = 'Sin conexión a internet.';
      }
      
      emit(state.copyWith(
        isLoading: false,
        errorMessage: errorMessage,
      ));
    }
  }

  void setPage(int page) {
    if (page >= 1 && page <= state.totalPages) {
      loadData(page: page);
    }
  }

  void setSearch(String query) {
    if (state.searchQuery != query) {
      loadData(query: query, page: 1);
    }
  }

  void setTab(int index) {
    bool nextDebtOnly = index == 1;
    if (state.withDebtOnly != nextDebtOnly) {
      loadData(withDebtOnly: nextDebtOnly, page: 1);
    }
  }

  Future<void> toggleAccountStatus(String creditId, bool isActive) async {
    try {
      await _toggleCreditStatusUseCase(creditId, isActive);
      await loadData();
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') || errStr.contains('clientexception') || errStr.contains('failed host lookup')) {
        throw Exception('Sin conexión a internet.');
      }
      throw Exception('Error al cambiar el estado del crédito.');
    }
  }

  Future<void> createCreditAccount(String customerId, double limit) async {
    try {
      await _createCreditAccountUseCase(
        customerId: customerId,
        creditLimit: limit,
      );
      await loadData(page: 1);
    } catch (e) {
      throw Exception('Error al crear la cuenta de crédito.');
    }
  }

  Future<void> registerPayment({
    required String creditId,
    required double amount,
    String? paymentMethod,
    String? notes,
  }) async {
    try {
      await _registerCreditPaymentUseCase(
        creditId: creditId,
        amount: amount,
        paymentMethod: paymentMethod,
        notes: notes,
      );
      await loadData();
    } catch (e) {
      throw Exception('Error al registrar el pago.');
    }
  }
}
