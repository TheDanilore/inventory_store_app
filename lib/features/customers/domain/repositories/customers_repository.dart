import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customers_global_stats_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customers_page_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/recent_order_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/top_product_entity.dart';

abstract class CustomersRepository {
  ({CustomersPageEntity data, bool isStale})? getCachedCustomersPage({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  });

  ({CustomersGlobalStatsEntity data, bool isStale})? getCachedGlobalStats();

  ({List<CustomerEntity> data, bool isStale})? getCachedTopCustomers({
    required int limit,
    DateTime? startDate,
    DateTime? endDate,
  });

  void invalidateCache();

  Future<Either<Failure, CustomersPageEntity>> getCustomers({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
    bool forceRefresh = false,
  });

  Future<Either<Failure, CustomerEntity>> getCustomerDetail(String customerId);

  Future<Either<Failure, CustomerEntity>> createCustomer({
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
  });

  Future<Either<Failure, CustomerEntity>> updateCustomer({
    required String customerId,
    required String fullName,
    String? phone,
    String? documentNumber,
    String? documentType,
    bool? isActive,
  });

  Future<Either<Failure, void>> saveCustomerFullProfile({
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
  });

  Future<Either<Failure, void>> toggleCustomerStatus(
    String customerId,
    bool isActive,
  );

  Future<Either<Failure, CustomersGlobalStatsEntity>> getGlobalStats({
    bool forceRefresh = false,
  });

  Future<Either<Failure, List<CustomerEntity>>> getTopCustomers(
    int limit, {
    DateTime? startDate,
    DateTime? endDate,
    bool forceRefresh = false,
  });

  Future<Either<Failure, List<RecentOrderEntity>>> getCustomerRecentOrders(
    String customerId,
  );

  Future<Either<Failure, List<TopProductEntity>>> getCustomerTopProducts(
    String customerId,
  );
}
