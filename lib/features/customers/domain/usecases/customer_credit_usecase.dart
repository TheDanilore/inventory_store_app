import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_list_result_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/customer_credits_repository.dart';

@lazySingleton
class GetCreditAccountsUseCase {
  final CustomerCreditsRepository repository;

  GetCreditAccountsUseCase(this.repository);

  ({CustomerCreditListResultEntity data, bool isStale})? getCached({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  }) {
    return repository.getCachedCreditAccountsPage(
      limit: limit,
      offset: offset,
      query: query,
      showOnlyWithDebt: showOnlyWithDebt,
    );
  }

  ({
    CustomerCreditListResultEntity data,
    String searchQuery,
    bool withDebtOnly,
    int page,
    int pageSize,
    bool isStale,
  })?
  getLatestSnapshot() => repository.getLatestCachedSnapshot();

  void invalidateCache() => repository.invalidateCache();

  Future<Either<Failure, CustomerCreditListResultEntity>> call({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
    bool forceRefresh = false,
  }) {
    return repository.getCreditAccounts(
      limit: limit,
      offset: offset,
      query: query,
      showOnlyWithDebt: showOnlyWithDebt,
      forceRefresh: forceRefresh,
    );
  }
}

@lazySingleton
class GetCreditAccountByCustomerUseCase {
  final CustomerCreditsRepository repository;

  GetCreditAccountByCustomerUseCase(this.repository);

  Future<Either<Failure, CustomerCreditEntity?>> call(String customerId) {
    return repository.getCreditAccountByCustomer(customerId);
  }
}

@lazySingleton
class SearchCustomersWithoutCreditUseCase {
  final CustomerCreditsRepository repository;

  SearchCustomersWithoutCreditUseCase(this.repository);

  Future<Either<Failure, List<CustomerEntity>>> call(
    String query, {
    int limit = 8,
  }) {
    return repository.searchCustomersWithoutCredit(query, limit: limit);
  }
}

@lazySingleton
class CreateCreditAccountUseCase {
  final CustomerCreditsRepository repository;

  CreateCreditAccountUseCase(this.repository);

  Future<Either<Failure, CustomerCreditEntity>> call({
    required String customerId,
    required double creditLimit,
  }) {
    return repository.createCreditAccount(
      customerId: customerId,
      creditLimit: creditLimit,
    );
  }
}

@lazySingleton
class UpdateCreditLimitUseCase {
  final CustomerCreditsRepository repository;

  UpdateCreditLimitUseCase(this.repository);

  Future<Either<Failure, CustomerCreditEntity>> call({
    required String creditId,
    required double newLimit,
  }) {
    return repository.updateCreditLimit(
      creditId: creditId,
      newLimit: newLimit,
    );
  }
}

@lazySingleton
class ToggleCreditStatusUseCase {
  final CustomerCreditsRepository repository;

  ToggleCreditStatusUseCase(this.repository);

  Future<Either<Failure, CustomerCreditEntity>> call(
    String creditId,
    bool isActive,
  ) {
    return repository.toggleCreditStatus(creditId, isActive);
  }
}

@lazySingleton
class GetCreditMovementsUseCase {
  final CustomerCreditsRepository repository;

  GetCreditMovementsUseCase(this.repository);

  Future<Either<Failure, ({List<CreditMovementEntity> items, int totalCount})>>
  call({
    required String creditId,
    required int limit,
    required int offset,
    String? dateFilter,
    String? movementType,
  }) {
    return repository.getCreditMovements(
      creditId: creditId,
      limit: limit,
      offset: offset,
      dateFilter: dateFilter,
      movementType: movementType,
    );
  }
}

@lazySingleton
class RegisterCreditPaymentUseCase {
  final CustomerCreditsRepository repository;

  RegisterCreditPaymentUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String customerId,
    required String creditId,
    required double amount,
    String? accountId,
    String? orderId,
    String? notes,
    String? shiftId,
    String? idempotencyKey,
  }) {
    return repository.registerPayment(
      customerId: customerId,
      creditId: creditId,
      amount: amount,
      accountId: accountId,
      orderId: orderId,
      notes: notes,
      shiftId: shiftId,
      idempotencyKey: idempotencyKey,
    );
  }
}
