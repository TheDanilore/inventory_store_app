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
  final List<AccountMovementEntity> previousMovements;
  final double totalIncome;
  final double totalExpense;
  final MovementFilters? filters;

  const AccountMovementsLoading({
    this.previousMovements = const [],
    this.totalIncome = 0.0,
    this.totalExpense = 0.0,
    this.filters,
  });

  @override
  List<Object?> get props => [
    previousMovements,
    totalIncome,
    totalExpense,
    filters,
  ];
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
  final List<AccountMovementEntity> previousMovements;

  const AccountMovementsError(
    this.message, {
    this.previousMovements = const [],
  });

  @override
  List<Object?> get props => [message, previousMovements];
}

/// Estado emitido mientras se guarda un movimiento.
class AccountMovementSaving extends AccountMovementsState {
  final List<AccountMovementEntity> previousMovements;
  final double totalIncome;
  final double totalExpense;

  const AccountMovementSaving({
    this.previousMovements = const [],
    this.totalIncome = 0.0,
    this.totalExpense = 0.0,
  });

  @override
  List<Object?> get props => [previousMovements, totalIncome, totalExpense];
}

class AccountMovementSaved extends AccountMovementsState {
  final List<AccountMovementEntity> previousMovements;

  const AccountMovementSaved({this.previousMovements = const []});

  @override
  List<Object?> get props => [previousMovements];
}

class AccountMovementSaveError extends AccountMovementsState {
  final String message;

  const AccountMovementSaveError(this.message);

  @override
  List<Object?> get props => [message];
}
