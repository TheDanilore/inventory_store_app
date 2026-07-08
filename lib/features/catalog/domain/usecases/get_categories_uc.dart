import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/catalog_repository.dart';

@lazySingleton
class GetCategoriesUC {
  final CatalogRepository repository;

  GetCategoriesUC(this.repository);

  Future<Either<Failure, List<CategoryEntity>>> call({bool activeOnly = false}) async {
    return await repository.getCategories(activeOnly: activeOnly);
  }
}