import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';

abstract class SuppliersRepository {
  ({SuppliersPageEntity data, bool isStale})? getCachedSuppliersPage({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool? filterIsActive,
  });

  ({
    SuppliersPageEntity data,
    String searchQuery,
    bool? filterIsActive,
    int page,
    int pageSize,
    bool isStale,
  })?
  getLatestCachedSnapshot();

  void invalidateCache();

  Future<Either<Failure, SuppliersPageEntity>> fetchSuppliers({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool? filterIsActive,
    bool forceRefresh = false,
  });

  Future<Either<Failure, List<SupplierEntity>>> getActiveSuppliers();

  Future<Either<Failure, SupplierEntity?>> toggleSupplierStatus(
    String supplierId,
    bool currentStatus,
  );

  Future<Either<Failure, List<SupplierEntity>>> bulkToggleSuppliersStatus(
    List<String> supplierIds,
  );

  Future<Either<Failure, SupplierEntity>> createSupplier(
    SupplierEntity supplier,
  );

  Future<Either<Failure, SupplierEntity>> updateSupplier(
    SupplierEntity supplier,
  );
}
