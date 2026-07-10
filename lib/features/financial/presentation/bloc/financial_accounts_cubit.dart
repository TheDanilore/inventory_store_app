import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/financial/domain/usecases/get_financial_accounts_usecase.dart';
import 'package:inventory_store_app/features/financial/domain/usecases/save_financial_account_usecase.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/financial_accounts_state.dart';

class FinancialAccountsCubit extends Cubit<FinancialAccountsState> {
  final GetFinancialAccountsUseCase _getAccounts;
  final SaveFinancialAccountUseCase _saveAccount;

  static const int _pageSize = 10;
  int _currentPage = 0;
  int _totalPages = 1;

  FinancialAccountsCubit({
    required GetFinancialAccountsUseCase getAccounts,
    required SaveFinancialAccountUseCase saveAccount,
  })  : _getAccounts = getAccounts,
        _saveAccount = saveAccount,
        super(const FinancialAccountsInitial());

  int get currentPage => _currentPage;
  int get totalPages => _totalPages;

  Future<void> fetchAccounts({int page = 0}) async {
    emit(const FinancialAccountsLoading());
    try {
      _currentPage = page;
      final accounts = await _getAccounts(
        page: page,
        pageSize: _pageSize,
      );
      // Calculamos totalPages a partir del resultado (si devolvemos menos que pageSize, es la última)
      if (accounts.length < _pageSize && page == 0) {
        _totalPages = 1;
      } else if (accounts.length < _pageSize) {
        _totalPages = page + 1;
      }

      emit(FinancialAccountsLoaded(
        accounts: accounts,
        currentPage: _currentPage,
        totalPages: _totalPages,
      ));
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        emit(const FinancialAccountsError('Sin conexión a internet.'));
      } else {
        emit(const FinancialAccountsError('Error al cargar cuentas financieras.'));
      }
    }
  }

  Future<void> setPage(int page) async {
    if (page >= 0 && page < _totalPages) {
      await fetchAccounts(page: page);
    }
  }

  Future<void> saveAccount({
    String? accountId,
    required String name,
    required String type,
    required bool isActive,
    double? initialBalance,
  }) async {
    emit(const FinancialAccountSaving());
    try {
      await _saveAccount(
        accountId: accountId,
        name: name,
        type: type,
        isActive: isActive,
        initialBalance: initialBalance,
      );
      emit(const FinancialAccountSaved());
      // Refresca la lista en la misma página
      await fetchAccounts(page: _currentPage);
    } catch (e) {
      emit(FinancialAccountSaveError(e.toString()));
    }
  }
}
