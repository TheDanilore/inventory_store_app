import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/suppliers_repository.dart';

@lazySingleton
class BulkToggleSuppliersStatusUseCase {
  final SuppliersRepository repository;

  BulkToggleSuppliersStatusUseCase(this.repository);

  Future<Either<Failure, List<SupplierEntity>>> call(List<String> supplierIds) {
    return repository.bulkToggleSuppliersStatus(supplierIds);
  }
}
