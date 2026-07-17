import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';

@lazySingleton
class GetProductByIdUseCase {
  final ProductsRepository repository;

  GetProductByIdUseCase(this.repository);

  Future<Either<Failure, ProductEntity?>> call(String id) {
    return repository.getProductById(id);
  }
}
