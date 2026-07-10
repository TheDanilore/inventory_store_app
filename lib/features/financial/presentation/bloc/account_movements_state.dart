import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/financial/domain/entities/account_movement_entity.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/account_movements_repository.dart';

abstract class AccountMovementsState extends Equatable {
  const AccountMovementsState();

  @override
  List<Object?> get props => [];
}

class AccountMovementsInitial extends AccountMovementsState {
  const AccountMovementsInitial();
}

class AccountMovementsLoading extends AccountMovementsState {
  const AccountMovementsLoading();
}

class AccountMovementsLoaded extends AccountMovementsState {
  final List<AccountMovementEntity> movements;
  final int currentPage;
  final int totalPages;
  final double totalIncome;
  final double totalExpense;
  final MovementFilters filters;

  const AccountMovementsLoaded({
    required this.movements,
    required this.currentPage,
    required this.totalPages,
    required this.totalIncome,
    required this.totalExpense,
    required this.filters,
  });

  @override
  List<Object?> get props => [
        movements,
        currentPage,
        totalPages,
        totalIncome,
        totalExpense,
        filters,
      ];
}

class AccountMovementsError extends AccountMovementsState {
  final String message;

  const AccountMovementsError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Estado emitido mientras se guarda un movimiento.
class AccountMovementSaving extends AccountMovementsState {
  const AccountMovementSaving();
}

class AccountMovementSaved extends AccountMovementsState {
  const AccountMovementSaved();
}

class AccountMovementSaveError extends AccountMovementsState {
  final String message;

  const AccountMovementSaveError(this.message);

  @override
  List<Object?> get props => [message];
}
