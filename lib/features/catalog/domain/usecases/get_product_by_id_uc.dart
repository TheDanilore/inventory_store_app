import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/catalog_repository.dart';

@lazySingleton
class GetProductByIdUC {
  final CatalogRepository repository;

  GetProductByIdUC(this.repository);

  Future<Either<Failure, ProductEntity?>> call(String id) async {
    return await repository.getProductById(id);
  }
}