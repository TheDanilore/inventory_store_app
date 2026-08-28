import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';

@injectable
class DeleteProductUC {
  final ProductsRepository repository;

  DeleteProductUC(this.repository);

  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteProduct(id);
  }
}
