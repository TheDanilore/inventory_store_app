import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/category_entity.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/catalog_repository.dart';

@lazySingleton
class CreateCategoryUC {
  final CatalogRepository repository;
  CreateCategoryUC(this.repository);
  Future<Either<Failure, CategoryEntity>> call({required String name, String? description, required bool isActive}) async {
    return await repository.createCategory(name: name, description: description, isActive: isActive);
  }
}

@lazySingleton
class UpdateCategoryUC {
  final CatalogRepository repository;
  UpdateCategoryUC(this.repository);
  Future<Either<Failure, void>> call({required String id, required String name, String? description, required bool isActive}) async {
    return await repository.updateCategory(id: id, name: name, description: description, isActive: isActive);
  }
}

@lazySingleton
class DeleteCategoryUC {
  final CatalogRepository repository;
  DeleteCategoryUC(this.repository);
  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteCategory(id);
  }
}
