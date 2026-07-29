import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';

abstract class SuppliersRepository {
  Future<Either<Failure, ({List<SupplierEntity> suppliers, int totalCount})>>
  fetchSuppliers({
    required int page,
    required int pageSize,
    String searchQuery = '',
  });

  Future<Either<Failure, void>> toggleSupplierStatus(
    String supplierId,
    bool currentStatus,
  );
}
