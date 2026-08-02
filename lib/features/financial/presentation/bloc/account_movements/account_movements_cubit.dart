import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/auth/domain/usecases/get_current_user_uc.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/account_movements_repository.dart';
import 'package:inventory_store_app/features/financial/domain/usecases/get_account_movements_usecase.dart';
import 'package:inventory_store_app/features/financial/domain/usecases/save_account_movement_usecase.dart';
import 'package:inventory_store_app/features/financial/domain/usecases/transfer_funds_usecase.dart';
import 'package:inventory_store_app/features/financial/domain/usecases/get_account_movement_totals_usecase.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/account_movements/account_movements_state.dart';
import 'dart:developer' as developer;

@injectable
class AccountMovementsCubit extends Cubit<AccountMovementsState> {
  final GetAccountMovementsUseCase _getMovements;
  final SaveAccountMovementUseCase _saveMovement;
  final TransferFundsUseCase _transferFunds;
  final GetCurrentUserUseCase _getCurrentUser;
  final GetAccountMovementTotalsUseCase _getTotals;

  static const int _pageSize = 15;
  int _currentPage = 0;
  int _totalPages = 1;
  MovementFilters _filters = const MovementFilters();

  AccountMovementsCubit({
    required GetAccountMovementsUseCase getMovements,
    required SaveAccountMovementUseCase saveMovement,
    required TransferFundsUseCase transferFunds,
    required GetCurrentUserUseCase getCurrentUser,
    required GetAccountMovementTotalsUseCase getTotals,
  }) : _getMovements = getMovements,
       _saveMovement = saveMovement,
       _transferFunds = transferFunds,
       _getCurrentUser = getCurrentUser,
       _getTotals = getTotals,
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

      // Calculamos totales con los mismos filtros activos desde la BD
      final totals = await _getTotals(filters: _filters);

      emit(
        AccountMovementsLoaded(
          movements: movements,
          currentPage: _currentPage,
          totalPages: _totalPages,
          totalIncome: totals.totalIncome,
          totalExpense: totals.totalExpense,
          filters: _filters,
        ),
      );
    } catch (e, st) {
      developer.log(
        'AccountMovementsCubit.fetchMovements ERROR',
        error: e,
        stackTrace: st,
      );
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('socketexception') ||
          errStr.contains('clientexception') ||
          errStr.contains('failed host lookup')) {
        emit(const AccountMovementsError('Sin conexión a internet.'));
      } else {
        emit(AccountMovementsError(e.toString()));
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
  }) async {
    emit(const AccountMovementSaving());
    try {
      final userResult = await _getCurrentUser(NoParams());
      final profileId = userResult.fold(
        (failure) => throw Exception(failure.message),
        (user) => user.id,
      );

      await _saveMovement(
        profileId: profileId,
        accountId: accountId,
        movementType: movementType,
        amount: amount,
        description: description,
      );
      emit(const AccountMovementSaved());
      await fetchMovements(page: _currentPage);
    } catch (e, st) {
      developer.log(
        'AccountMovementsCubit.saveMovement ERROR',
        error: e,
        stackTrace: st,
      );
      emit(AccountMovementSaveError(e.toString()));
    }
  }

  Future<void> transferFunds({
    required String sourceAccountId,
    required String destAccountId,
    required double amount,
    required String description,
  }) async {
    emit(const AccountMovementSaving());
    try {
      final userResult = await _getCurrentUser(NoParams());
      final profileId = userResult.fold(
        (failure) => throw Exception(failure.message),
        (user) => user.id,
      );

      await _transferFunds(
        profileId: profileId,
        sourceAccountId: sourceAccountId,
        destAccountId: destAccountId,
        amount: amount,
        description: description,
      );
      emit(const AccountMovementSaved());
      await fetchMovements(page: _currentPage);
    } catch (e, st) {
      developer.log(
        'AccountMovementsCubit.transferFunds ERROR',
        error: e,
        stackTrace: st,
      );
      emit(AccountMovementSaveError(e.toString()));
    }
  }
}
