import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/suppliers_repository.dart';

@injectable
@lazySingleton
class GetActiveSuppliersUseCase {
  final SuppliersRepository repository;

  GetActiveSuppliersUseCase(this.repository);

  Future<Either<Failure, List<SupplierEntity>>> call() async {
    return await repository.getActiveSuppliers();
  }
}
