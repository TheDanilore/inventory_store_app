import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';

abstract class FinancialAccountsState extends Equatable {
  const FinancialAccountsState();

  @override
  List<Object?> get props => [];
}

class FinancialAccountsInitial extends FinancialAccountsState {
  const FinancialAccountsInitial();
}

class FinancialAccountsLoading extends FinancialAccountsState {
  const FinancialAccountsLoading();
}

class FinancialAccountsLoaded extends FinancialAccountsState {
  final List<FinancialAccountEntity> accounts;
  final int currentPage;
  final int totalPages;

  const FinancialAccountsLoaded({
    required this.accounts,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  List<Object?> get props => [accounts, currentPage, totalPages];
}

class FinancialAccountsError extends FinancialAccountsState {
  final String message;

  const FinancialAccountsError(this.message);

  @override
  List<Object?> get props => [message];
}

/// Estado emitido mientras se guarda una cuenta (crear/editar).
class FinancialAccountSaving extends FinancialAccountsState {
  final List<FinancialAccountEntity> previousAccounts;
  const FinancialAccountSaving({this.previousAccounts = const []});

  @override
  List<Object?> get props => [previousAccounts];
}

class FinancialAccountSaved extends FinancialAccountsState {
  final List<FinancialAccountEntity> accounts;
  const FinancialAccountSaved({this.accounts = const []});

  @override
  List<Object?> get props => [accounts];
}

class FinancialAccountSaveError extends FinancialAccountsState {
  final String message;
  final List<FinancialAccountEntity> previousAccounts;

  const FinancialAccountSaveError(
    this.message, {
    this.previousAccounts = const [],
  });

  @override
  List<Object?> get props => [message, previousAccounts];
}
