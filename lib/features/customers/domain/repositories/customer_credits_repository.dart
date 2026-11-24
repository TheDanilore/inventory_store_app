import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_credit_list_result_entity.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

abstract class CustomerCreditsRepository {
  ({CustomerCreditListResultEntity data, bool isStale})?
  getCachedCreditAccountsPage({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
  });

  ({
    CustomerCreditListResultEntity data,
    String searchQuery,
    bool withDebtOnly,
    int page,
    int pageSize,
    bool isStale,
  })?
  getLatestCachedSnapshot();

  void invalidateCache();

  Future<Either<Failure, CustomerCreditListResultEntity>> getCreditAccounts({
    required int limit,
    required int offset,
    String? query,
    bool showOnlyWithDebt = false,
    bool forceRefresh = false,
  });

  Future<Either<Failure, CustomerCreditEntity?>> getCreditAccountByCustomer(
    String customerId,
  );

  Future<Either<Failure, List<CustomerEntity>>> searchCustomersWithoutCredit(
    String query, {
    int limit = 8,
  });

  Future<Either<Failure, CustomerCreditEntity>> createCreditAccount({
    required String customerId,
    required double creditLimit,
  });

  Future<Either<Failure, CustomerCreditEntity>> updateCreditLimit({
    required String creditId,
    required double newLimit,
  });

  Future<Either<Failure, CustomerCreditEntity>> toggleCreditStatus(
    String creditId,
    bool isActive,
  );

  Future<Either<Failure, ({List<CreditMovementEntity> items, int totalCount})>>
  getCreditMovements({
    required String creditId,
    required int limit,
    required int offset,
    String? dateFilter,
    String? movementType,
  });

  Future<
    Either<
      Failure,
      ({
        double totalCharged,
        double totalPaid,
        int chargeCount,
        int paymentCount,
      })
    >
  >
  getCreditMovementsTotals({required String creditId, String? dateFilter});

  Future<Either<Failure, void>> registerPayment({
    required String customerId,
    required String creditId,
    required double amount,
    String? accountId,
    String? orderId,
    String? notes,
    String? shiftId,
    String? idempotencyKey,
  });
}
