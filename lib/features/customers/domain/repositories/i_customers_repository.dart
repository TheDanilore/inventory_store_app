import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

abstract class ICustomersRepository {
  Future<List<CustomerEntity>> getCustomers({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  });

  Future<CustomerEntity> getCustomerDetail(String customerId);

  Future<CustomerEntity> createCustomer({
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
  });

  Future<CustomerEntity> updateCustomer({
    required String customerId,
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
    bool? isActive,
  });

  Future<void> toggleCustomerStatus(String customerId, bool isActive);

  // Stats y KPI
  Future<Map<String, dynamic>> getGlobalStats();
  Future<List<CustomerEntity>> getTopCustomers(int limit);
}
