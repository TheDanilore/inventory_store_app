import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/active_ingredient_entity.dart';

abstract class IngredientsRepository {
  Future<Either<Failure, List<Map<String, dynamic>>>> getProductIngredients(
    String productId,
  );
  Future<Either<Failure, List<ActiveIngredientEntity>>> searchIngredients(
    String term,
  );
  Future<Either<Failure, ActiveIngredientEntity>> createIngredient(String name);
  Future<Either<Failure, void>> updateIngredient(String id, String name);
  Future<Either<Failure, void>> deleteIngredient(String id);
  Future<Either<Failure, List<ActiveIngredientEntity>>> getIngredients({
    String? searchQuery,
    int limit = 20,
    int offset = 0,
  });
  Future<Either<Failure, void>> clearProductIngredients(String productId);
  Future<Either<Failure, void>> insertProductIngredient(
    Map<String, dynamic> payload,
  );
}
