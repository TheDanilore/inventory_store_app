import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';

abstract class SupplierCreditsRepository {
  Future<
    Either<
      Failure,
      ({
        List<SupplierCreditEntity> accounts,
        int count,
        Map<String, dynamic> stats,
      })
    >
  >
  fetchAccountsPaginated({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool withDebtOnly = false,
  });

  Future<Either<Failure, void>> toggleAccountStatus(
    String creditId,
    bool currentStatus,
  );

  Future<Either<Failure, void>> saveAccount({
    required String? creditId,
    required String supplierId,
    required double creditLimit,
    String? adminProfileId,
  });

  Future<Either<Failure, List<Map<String, dynamic>>>> searchSuppliers(
    String query,
    Set<String> existingSupplierIds,
  );

  Future<Either<Failure, Set<String>>> getExistingCreditSupplierIds({
    String? excludeSupplierId,
  });

  Future<Either<Failure, List<Map<String, dynamic>>>> getPendingPurchaseOrders(
    String supplierId,
  );

  Future<Either<Failure, List<SupplierFinancialAccountOption>>>
  getFinancialAccounts();

  Future<Either<Failure, Map<String, dynamic>?>> getActiveCashShift(
    String accountId,
  );

  Future<Either<Failure, String?>> getAdminProfileId();

  Future<Either<Failure, void>> registerPayment({
    required String supplierId,
    required String creditId,
    required double amount,
    required String? accountId,
    required String? orderId,
    required String notes,
    required String? shiftId,
    required String? adminProfileId,
  });
}
