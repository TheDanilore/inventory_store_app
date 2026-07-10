import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/active_ingredient_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/catalog_repository.dart';

@lazySingleton
class GetAttributesUC {
  final CatalogRepository repository;
  GetAttributesUC(this.repository);
  Future<Either<Failure, List<Map<String, dynamic>>>> call() async {
    return await repository.getAttributes();
  }
}

@lazySingleton
class GetProductIngredientsUC {
  final CatalogRepository repository;
  GetProductIngredientsUC(this.repository);
  Future<Either<Failure, List<Map<String, dynamic>>>> call(
    String productId,
  ) async {
    return await repository.getProductIngredients(productId);
  }
}

@lazySingleton
class SearchIngredientsUC {
  final CatalogRepository repository;
  SearchIngredientsUC(this.repository);
  Future<Either<Failure, List<ActiveIngredientEntity>>> call(
    String term,
  ) async {
    return await repository.searchIngredients(term);
  }
}

@lazySingleton
class CreateIngredientUC {
  final CatalogRepository repository;
  CreateIngredientUC(this.repository);
  Future<Either<Failure, ActiveIngredientEntity>> call(String name) async {
    return await repository.createIngredient(name);
  }
}

@lazySingleton
class ClearProductIngredientsUC {
  final CatalogRepository repository;
  ClearProductIngredientsUC(this.repository);
  Future<Either<Failure, void>> call(String productId) async {
    return await repository.clearProductIngredients(productId);
  }
}

@lazySingleton
class InsertProductIngredientUC {
  final CatalogRepository repository;
  InsertProductIngredientUC(this.repository);
  Future<Either<Failure, void>> call(Map<String, dynamic> payload) async {
    return await repository.insertProductIngredient(payload);
  }
}
