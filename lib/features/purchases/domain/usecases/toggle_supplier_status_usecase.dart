import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/suppliers_repository.dart';

@lazySingleton
class ToggleSupplierStatusUseCase {
  final SuppliersRepository repository;

  ToggleSupplierStatusUseCase(this.repository);

  Future<Either<Failure, void>> call(String supplierId, bool currentStatus) {
    return repository.toggleSupplierStatus(supplierId, currentStatus);
  }
}
