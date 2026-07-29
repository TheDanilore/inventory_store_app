import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';

@lazySingleton
class GetProductStockUC {
  final ProductsRepository repository;

  GetProductStockUC(this.repository);

  Future<Either<Failure, Map<String, int>>> call({
    List<String>? productIds,
  }) async {
    return await repository.getProductStock(productIds: productIds);
  }
}
