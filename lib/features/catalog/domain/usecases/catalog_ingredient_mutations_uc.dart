import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/active_ingredient_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/ingredients_repository.dart';

@lazySingleton
class UpdateIngredientUC {
  final IngredientsRepository repository;
  UpdateIngredientUC(this.repository);
  Future<Either<Failure, void>> call(String id, String name) async {
    return await repository.updateIngredient(id, name);
  }
}

@lazySingleton
class DeleteIngredientUC {
  final IngredientsRepository repository;
  DeleteIngredientUC(this.repository);
  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteIngredient(id);
  }
}

@lazySingleton
class GetIngredientsUC {
  final IngredientsRepository repository;
  GetIngredientsUC(this.repository);
  Future<Either<Failure, List<ActiveIngredientEntity>>> call({
    String? searchQuery,
    int limit = 20,
    int offset = 0,
  }) async {
    return await repository.getIngredients(
      searchQuery: searchQuery,
      limit: limit,
      offset: offset,
    );
  }
}
