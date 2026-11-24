import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/suppliers_repository.dart';

@lazySingleton
class ToggleSupplierStatusUseCase {
  final SuppliersRepository repository;

  ToggleSupplierStatusUseCase(this.repository);

  Future<Either<Failure, SupplierEntity?>> call(
    String supplierId,
    bool currentStatus,
  ) {
    return repository.toggleSupplierStatus(supplierId, currentStatus);
  }
}
