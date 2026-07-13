import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/active_ingredient_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/ingredients_repository.dart';

@lazySingleton
class CreateIngredientUC {
  final IngredientsRepository repository;
  CreateIngredientUC(this.repository);
  Future<Either<Failure, ActiveIngredientEntity>> call(String name) async {
    return await repository.createIngredient(name);
  }
}
