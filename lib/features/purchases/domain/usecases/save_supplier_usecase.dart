import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/suppliers_repository.dart';

@lazySingleton
class SaveSupplierUseCase implements UseCase<SupplierEntity, SupplierEntity> {
  final SuppliersRepository repository;

  SaveSupplierUseCase(this.repository);

  @override
  Future<Either<Failure, SupplierEntity>> call(SupplierEntity supplier) async {
    if (supplier.id.isEmpty) {
      return await repository.createSupplier(supplier);
    } else {
      return await repository.updateSupplier(supplier);
    }
  }
}
