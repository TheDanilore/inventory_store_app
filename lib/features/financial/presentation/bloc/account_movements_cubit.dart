import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/account_movements_repository.dart';
import 'package:inventory_store_app/features/financial/domain/usecases/get_account_movements_usecase.dart';
import 'package:inventory_store_app/features/financial/domain/usecases/save_account_movement_usecase.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/account_movements_state.dart';

class AccountMovementsCubit extends Cubit<AccountMovementsState> {
  final GetAccountMovementsUseCase _getMovements;
  final SaveAccountMovementUseCase _saveMovement;

  static const int _pageSize = 15;
  int _currentPage = 0;
  int _totalPages = 1;
  MovementFilters _filters = const MovementFilters();

  AccountMovementsCubit({
    required GetAccountMovementsUseCase getMovements,
    required SaveAccountMovementUseCase saveMovement,
  })  : _getMovements = getMovements,
        _saveMovement = saveMovement,
        super(const AccountMovementsInitial());

  MovementFilters get filters => _filters;

  Future<void> fetchMovements({int page = 0}) async {
    emit(const AccountMovementsLoading());
    try {
      _currentPage = page;
      final movements = await _getMovements(
        filters: _filters,
        page: page,
        pageSize: _pageSize,
      );

      if (movements.length < _pageSize && page == 0) {
        _totalPages = 1;
      } else if (movements.length < _pageSize) {
        _totalPages = page + 1;
      }

      // Calculamos totales con los mismos filtros activos
      double totalIncome = 0;
      double totalExpense = 0;
      for (final m in movements) {
        if (m.movementType == 'INCOME') totalIncome += m.amount;
        if (m.movementType == 'EXPENSE') totalExpense += m.amount;
      }

      emit(AccountMovementsLoaded(
        movements: movements,
        currentPage: _currentPage,
        totalPages: _totalPages,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        filters: _filters,
      ));
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        emit(const AccountMovementsError('Sin conexión a internet.'));
      } else {
        emit(const AccountMovementsError('Error al cargar los movimientos.'));
      }
    }
  }

  void setFilterType(String type) {
    _filters = MovementFilters(
      filterType: type,
      filterAccountId: _filters.filterAccountId,
      searchText: _filters.searchText,
      dateFrom: _filters.dateFrom,
      dateTo: _filters.dateTo,
    );
    fetchMovements();
  }

  void setFilterAccount(String accountId) {
    _filters = MovementFilters(
      filterType: _filters.filterType,
      filterAccountId: accountId,
      searchText: _filters.searchText,
      dateFrom: _filters.dateFrom,
      dateTo: _filters.dateTo,
    );
    fetchMovements();
  }

  void setSearchText(String text) {
    _filters = MovementFilters(
      filterType: _filters.filterType,
      filterAccountId: _filters.filterAccountId,
      searchText: text,
      dateFrom: _filters.dateFrom,
      dateTo: _filters.dateTo,
    );
    fetchMovements();
  }

  void setDateRange(DateTime? from, DateTime? to) {
    _filters = MovementFilters(
      filterType: _filters.filterType,
      filterAccountId: _filters.filterAccountId,
      searchText: _filters.searchText,
      dateFrom: from,
      dateTo: to,
    );
    fetchMovements();
  }

  void setPage(int page) {
    if (page >= 0 && page < _totalPages) {
      fetchMovements(page: page);
    }
  }

  Future<void> saveMovement({
    required String accountId,
    required String movementType,
    required double amount,
    required String description,
    String? referenceType,
    String? referenceId,
  }) async {
    emit(const AccountMovementSaving());
    try {
      await _saveMovement(
        accountId: accountId,
        movementType: movementType,
        amount: amount,
        description: description,
        referenceType: referenceType,
        referenceId: referenceId,
      );
      emit(const AccountMovementSaved());
      await fetchMovements(page: _currentPage);
    } catch (e) {
      emit(AccountMovementSaveError(e.toString()));
    }
  }
}
