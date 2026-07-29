import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';

/// Usado por ProductFormScreen cuando se entra directo a
/// /admin/products/product-form/:id (deep-link o refresh del navegador) y no llegó
/// el ProductEntity completo por `extra` de go_router.
@lazySingleton
class GetProductByIdUC {
  final ProductsRepository repository;
  GetProductByIdUC(this.repository);

  Future<Either<Failure, ProductEntity?>> call(String id) {
    return repository.getProductById(id);
  }
}
