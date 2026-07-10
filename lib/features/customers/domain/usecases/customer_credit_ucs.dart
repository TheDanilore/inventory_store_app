import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/i_customer_credits_repository.dart';

@lazySingleton
class GetCreditAccountsUseCase {
  final ICustomerCreditsRepository repository;

  GetCreditAccountsUseCase(this.repository);

  Future<List<CustomerCreditEntity>> call({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  }) {
    return repository.getCreditAccounts(
      limit: limit,
      offset: offset,
      query: query,
      showOnlyWithDebt: showOnlyWithDebt,
    );
  }
}

@lazySingleton
class GetCreditAccountByCustomerUseCase {
  final ICustomerCreditsRepository repository;

  GetCreditAccountByCustomerUseCase(this.repository);

  Future<CustomerCreditEntity?> call(String customerId) {
    return repository.getCreditAccountByCustomer(customerId);
  }
}

@lazySingleton
class CreateCreditAccountUseCase {
  final ICustomerCreditsRepository repository;

  CreateCreditAccountUseCase(this.repository);

  Future<CustomerCreditEntity> call({
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
  final ICustomerCreditsRepository repository;

  UpdateCreditLimitUseCase(this.repository);

  Future<CustomerCreditEntity> call({
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
  final ICustomerCreditsRepository repository;

  ToggleCreditStatusUseCase(this.repository);

  Future<void> call(String creditId, bool isActive) {
    return repository.toggleCreditStatus(creditId, isActive);
  }
}

@lazySingleton
class GetCreditMovementsUseCase {
  final ICustomerCreditsRepository repository;

  GetCreditMovementsUseCase(this.repository);

  Future<List<CreditMovementEntity>> call({
    required String creditId,
    required int limit,
    required int offset,
  }) {
    return repository.getCreditMovements(
      creditId: creditId,
      limit: limit,
      offset: offset,
    );
  }
}

@lazySingleton
class RegisterCreditPaymentUseCase {
  final ICustomerCreditsRepository repository;

  RegisterCreditPaymentUseCase(this.repository);

  Future<CreditMovementEntity> call({
    required String creditId,
    required double amount,
    String? paymentMethod,
    String? notes,
  }) {
    return repository.registerPayment(
      creditId: creditId,
      amount: amount,
      paymentMethod: paymentMethod,
      notes: notes,
    );
  }
}
