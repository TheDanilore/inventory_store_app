import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/active_ingredient_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/ingredients_repository.dart';

@lazySingleton
class GetProductIngredientsUC {
  final IngredientsRepository repository;
  GetProductIngredientsUC(this.repository);
  Future<Either<Failure, List<Map<String, dynamic>>>> call(
    String productId,
  ) async {
    return await repository.getProductIngredients(productId);
  }
}

@lazySingleton
class SearchIngredientsUC {
  final IngredientsRepository repository;
  SearchIngredientsUC(this.repository);
  Future<Either<Failure, List<ActiveIngredientEntity>>> call(
    String term,
  ) async {
    return await repository.searchIngredients(term);
  }
}

@lazySingleton
class CreateIngredientUC {
  final IngredientsRepository repository;
  CreateIngredientUC(this.repository);
  Future<Either<Failure, ActiveIngredientEntity>> call(String name) async {
    return await repository.createIngredient(name);
  }
}

@lazySingleton
class ClearProductIngredientsUC {
  final IngredientsRepository repository;
  ClearProductIngredientsUC(this.repository);
  Future<Either<Failure, void>> call(String productId) async {
    return await repository.clearProductIngredients(productId);
  }
}

@lazySingleton
class InsertProductIngredientUC {
  final IngredientsRepository repository;
  InsertProductIngredientUC(this.repository);
  Future<Either<Failure, void>> call(Map<String, dynamic> payload) async {
    return await repository.insertProductIngredient(payload);
  }
}
