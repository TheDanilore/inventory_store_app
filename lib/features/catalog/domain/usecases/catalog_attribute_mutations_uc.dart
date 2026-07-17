import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';

@lazySingleton
class CreateAttributeUseCase {
  final ProductsRepository repository;
  CreateAttributeUseCase(this.repository);
  Future<Either<Failure, Map<String, dynamic>>> call(String name) async {
    return await repository.createAttribute(name);
  }
}

@lazySingleton
class UpdateAttributeUC {
  final ProductsRepository repository;
  UpdateAttributeUC(this.repository);
  Future<Either<Failure, void>> call(String id, String name) async {
    return await repository.updateAttribute(id, name);
  }
}

@lazySingleton
class DeleteAttributeUC {
  final ProductsRepository repository;
  DeleteAttributeUC(this.repository);
  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteAttribute(id);
  }
}

@lazySingleton
class CreateAttributeValueUC {
  final ProductsRepository repository;
  CreateAttributeValueUC(this.repository);
  Future<Either<Failure, Map<String, dynamic>>> call(
    String attributeId,
    String value,
  ) async {
    return await repository.createAttributeValue(attributeId, value);
  }
}

@lazySingleton
class UpdateAttributeValueUC {
  final ProductsRepository repository;
  UpdateAttributeValueUC(this.repository);
  Future<Either<Failure, void>> call(String valueId, String value) async {
    return await repository.updateAttributeValue(valueId, value);
  }
}

@lazySingleton
class DeleteAttributeValueUC {
  final ProductsRepository repository;
  DeleteAttributeValueUC(this.repository);
  Future<Either<Failure, void>> call(String valueId) async {
    return await repository.deleteAttributeValue(valueId);
  }
}
