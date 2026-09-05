import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/auth/domain/usecases/get_current_user_uc.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/account_movements_repository.dart';
import 'package:inventory_store_app/features/financial/domain/usecases/get_account_movements_usecase.dart';
import 'package:inventory_store_app/features/financial/domain/usecases/save_account_movement_usecase.dart';
import 'package:inventory_store_app/features/financial/domain/usecases/transfer_funds_usecase.dart';
import 'package:inventory_store_app/features/financial/domain/usecases/get_account_movement_totals_usecase.dart';
import 'package:inventory_store_app/features/financial/presentation/bloc/account_movements/account_movements_state.dart';

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
  Timer? _searchDebounce;

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
      final result = await _getMovements(
        filters: _filters,
        page: page,
        pageSize: _pageSize,
      );

      final totalPages = (result.totalCount / _pageSize).ceil();
      _totalPages = totalPages > 0 ? totalPages : 1;

      // Calculamos totales con los mismos filtros activos desde la BD
      final totals = await _getTotals(filters: _filters);

      emit(
        AccountMovementsLoaded(
          movements: result.items,
          currentPage: _currentPage,
          totalPages: _totalPages,
          totalIncome: totals.totalIncome,
          totalExpense: totals.totalExpense,
          filters: _filters,
        ),
      );
    } catch (e, st) {
      LoggerService.e(
        'AccountMovementsCubit.fetchMovements ERROR',
        tag: 'ACCOUNT_MOVEMENTS_CUBIT',
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
    fetchMovements(page: 0);
  }

  void setFilterAccount(String accountId) {
    _filters = MovementFilters(
      filterType: _filters.filterType,
      filterAccountId: accountId,
      searchText: _filters.searchText,
      dateFrom: _filters.dateFrom,
      dateTo: _filters.dateTo,
    );
    fetchMovements(page: 0);
  }

  void setSearchText(String text) {
    _filters = MovementFilters(
      filterType: _filters.filterType,
      filterAccountId: _filters.filterAccountId,
      searchText: text,
      dateFrom: _filters.dateFrom,
      dateTo: _filters.dateTo,
    );
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      fetchMovements(page: 0);
    });
  }

  void setDateRange(DateTime? from, DateTime? to) {
    _filters = MovementFilters(
      filterType: _filters.filterType,
      filterAccountId: _filters.filterAccountId,
      searchText: _filters.searchText,
      dateFrom: from,
      dateTo: to,
    );
    fetchMovements(page: 0);
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
      LoggerService.e(
        'AccountMovementsCubit.saveMovement ERROR',
        tag: 'ACCOUNT_MOVEMENTS_CUBIT',
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
      LoggerService.e(
        'AccountMovementsCubit.transferFunds ERROR',
        tag: 'ACCOUNT_MOVEMENTS_CUBIT',
        error: e,
        stackTrace: st,
      );
      emit(AccountMovementSaveError(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _searchDebounce?.cancel();
    return super.close();
  }
}
