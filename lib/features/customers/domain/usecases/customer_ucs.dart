import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/i_customers_repository.dart';

@lazySingleton
class GetCustomersUseCase {
  final ICustomersRepository repository;

  GetCustomersUseCase(this.repository);

  Future<List<CustomerEntity>> call({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  }) {
    return repository.getCustomers(
      limit: limit,
      offset: offset,
      query: query,
      showOnlyWithDebt: showOnlyWithDebt,
    );
  }
}

@lazySingleton
class GetCustomerDetailUseCase {
  final ICustomersRepository repository;

  GetCustomerDetailUseCase(this.repository);

  Future<CustomerEntity> call(String customerId) {
    return repository.getCustomerDetail(customerId);
  }
}

@lazySingleton
class GetGlobalStatsUseCase {
  final ICustomersRepository repository;

  GetGlobalStatsUseCase(this.repository);

  Future<Map<String, dynamic>> call() {
    return repository.getGlobalStats();
  }
}

@lazySingleton
class GetTopCustomersUseCase {
  final ICustomersRepository repository;

  GetTopCustomersUseCase(this.repository);

  Future<List<CustomerEntity>> call(int limit) {
    return repository.getTopCustomers(limit);
  }
}

@lazySingleton
class CreateCustomerUseCase {
  final ICustomersRepository repository;

  CreateCustomerUseCase(this.repository);

  Future<CustomerEntity> call({
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
  final ICustomersRepository repository;

  UpdateCustomerUseCase(this.repository);

  Future<CustomerEntity> call({
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
  final ICustomersRepository repository;

  ToggleCustomerStatusUseCase(this.repository);

  Future<void> call(String customerId, bool isActive) {
    return repository.toggleCustomerStatus(customerId, isActive);
  }
}
