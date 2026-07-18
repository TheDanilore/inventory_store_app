import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';

abstract class CategoriesRepository {
  Future<Either<Failure, CategoryEntity>> createCategory({
    required String name,
    String? description,
    required bool isActive,
    String? profileId,
  });

  Future<Either<Failure, void>> updateCategory({
    required String id,
    required String name,
    String? description,
    required bool isActive,
    String? profileId,
  });

  Future<Either<Failure, void>> deleteCategory(String id);

  Future<Either<Failure, List<CategoryEntity>>> getCategories({
    bool activeOnly = false,
  });
}
