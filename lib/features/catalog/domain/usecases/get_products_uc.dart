import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/catalog_repository.dart';

@lazySingleton
class GetProductsUC {
  final CatalogRepository repository;

  GetProductsUC(this.repository);

  Future<Either<Failure, ({List<ProductEntity> products, int totalCount})>> call({
    String? searchQuery,
    String? categoryId,
    bool? isActive,
    int limit = 20,
    int offset = 0,
    bool sortByPriceAsc = true,
  }) async {
    return await repository.getProducts(
      searchQuery: searchQuery,
      categoryId: categoryId,
      isActive: isActive,
      limit: limit,
      offset: offset,
      sortByPriceAsc: sortByPriceAsc,
    );
  }
}