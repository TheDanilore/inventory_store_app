import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';

@lazySingleton
class SaveProductUseCase {
  final ProductsRepository repository;

  SaveProductUseCase(this.repository);

  Future<Either<Failure, void>> call(SaveProductPayload payload) async {
    return repository.saveProductComplete(payload);
  }
}
