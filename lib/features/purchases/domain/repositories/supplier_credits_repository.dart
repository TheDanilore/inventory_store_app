import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';

abstract class SupplierCreditsRepository {
  ({SupplierCreditsPageEntity data, bool isStale})? getCachedAccountsPage({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool withDebtOnly = false,
  });

  ({
    SupplierCreditsPageEntity data,
    String searchQuery,
    bool withDebtOnly,
    int page,
    int pageSize,
    bool isStale,
  })?
  getLatestCachedSnapshot();

  void invalidateCache();

  Future<Either<Failure, SupplierCreditsPageEntity>> fetchAccountsPaginated({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool withDebtOnly = false,
    bool forceRefresh = false,
  });

  Future<Either<Failure, SupplierCreditEntity?>> toggleAccountStatus(
    String creditId,
    bool currentStatus,
  );

  Future<Either<Failure, SupplierCreditEntity?>> saveAccount({
    required String? creditId,
    required String supplierId,
    required double creditLimit,
    String? adminProfileId,
  });

  Future<Either<Failure, SupplierCreditEntity?>> registerPayment({
    required String supplierId,
    required String creditId,
    required double amount,
    required String? accountId,
    required String? orderId,
    required String notes,
    required String? shiftId,
    String? adminProfileId,
    String? idempotencyKey,
  });

  Future<Either<Failure, List<SupplierCandidateEntity>>>
  searchAvailableSuppliers(String query);

  Future<Either<Failure, List<PendingPurchaseOrderEntity>>>
  getPendingPurchaseOrdersTyped(String supplierId);

  Future<Either<Failure, List<SupplierFinancialAccountOption>>>
  getFinancialAccounts();

  Future<Either<Failure, ActiveCashShiftEntity?>> getActiveCashShiftTyped(
    String accountId,
  );

  // Métodos legados mantenidos para compatibilidad con otros flujos de compras
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

  Future<Either<Failure, Map<String, dynamic>?>> getActiveCashShift(
    String accountId,
  );

  Future<Either<Failure, String?>> getAdminProfileId();
}
