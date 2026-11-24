import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customers_global_stats_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customers_page_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/customers_repository.dart';

@lazySingleton
class GetCustomersUseCase {
  final CustomersRepository repository;

  GetCustomersUseCase(this.repository);

  ({CustomersPageEntity data, bool isStale})? getCached({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  }) {
    return repository.getCachedCustomersPage(
      limit: limit,
      offset: offset,
      query: query,
      showOnlyWithDebt: showOnlyWithDebt,
    );
  }

  void invalidateCache() => repository.invalidateCache();

  Future<Either<Failure, CustomersPageEntity>> call({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
    bool forceRefresh = false,
  }) {
    return repository.getCustomers(
      limit: limit,
      offset: offset,
      query: query,
      showOnlyWithDebt: showOnlyWithDebt,
      forceRefresh: forceRefresh,
    );
  }
}

@lazySingleton
class GetCustomerDetailUseCase {
  final CustomersRepository repository;

  GetCustomerDetailUseCase(this.repository);

  Future<Either<Failure, CustomerEntity>> call(String customerId) {
    return repository.getCustomerDetail(customerId);
  }
}

@lazySingleton
class GetGlobalStatsUseCase {
  final CustomersRepository repository;

  GetGlobalStatsUseCase(this.repository);

  ({CustomersGlobalStatsEntity data, bool isStale})? getCached() {
    return repository.getCachedGlobalStats();
  }

  Future<Either<Failure, CustomersGlobalStatsEntity>> call({
    bool forceRefresh = false,
  }) {
    return repository.getGlobalStats(forceRefresh: forceRefresh);
  }
}

@lazySingleton
class GetTopCustomersUseCase {
  final CustomersRepository repository;

  GetTopCustomersUseCase(this.repository);

  ({List<CustomerEntity> data, bool isStale})? getCached(
    int limit, {
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return repository.getCachedTopCustomers(
      limit: limit,
      startDate: startDate,
      endDate: endDate,
    );
  }

  Future<Either<Failure, List<CustomerEntity>>> call(
    int limit, {
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  }) {
    return repository.getTopCustomers(
      limit,
      startDate: startDate,
      endDate: endDate,
      forceRefresh: forceRefresh,
    );
  }
}

@lazySingleton
class CreateCustomerUseCase {
  final CustomersRepository repository;

  CreateCustomerUseCase(this.repository);

  Future<Either<Failure, CustomerEntity>> call({
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
  }) {
    return repository.createCustomer(
      fullName: fullName,
      phone: phone,
      documentNumber: documentNumber,
      documentType: documentType,
    );
  }
}

@lazySingleton
class UpdateCustomerUseCase {
  final CustomersRepository repository;

  UpdateCustomerUseCase(this.repository);

  Future<Either<Failure, CustomerEntity>> call({
    required String customerId,
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
    bool? isActive,
  }) {
    return repository.updateCustomer(
      customerId: customerId,
      fullName: fullName,
      phone: phone,
      documentNumber: documentNumber,
      documentType: documentType,
      isActive: isActive,
    );
  }
}

@lazySingleton
class ToggleCustomerStatusUseCase {
  final CustomersRepository repository;

  ToggleCustomerStatusUseCase(this.repository);

  Future<Either<Failure, void>> call(String customerId, bool isActive) {
    return repository.toggleCustomerStatus(customerId, isActive);
  }
}

@lazySingleton
class SaveCustomerFullProfileUseCase {
  final CustomersRepository repository;

  SaveCustomerFullProfileUseCase(this.repository);

  Future<Either<Failure, void>> call({
    String? customerId,
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
    required bool isActive,
    required int walletAdjustDelta,
    required double currentWalletBalance,
    required bool hasCredit,
    required bool creditExistsInDb,
    String? creditId,
    required bool creditIsActive,
    required double newCreditLimit,
  }) {
    return repository.saveCustomerFullProfile(
      customerId: customerId,
      fullName: fullName,
      phone: phone,
      documentNumber: documentNumber,
      documentType: documentType,
      isActive: isActive,
      walletAdjustDelta: walletAdjustDelta,
      currentWalletBalance: currentWalletBalance,
      hasCredit: hasCredit,
      creditExistsInDb: creditExistsInDb,
      creditId: creditId,
      creditIsActive: creditIsActive,
      newCreditLimit: newCreditLimit,
    );
  }
}
