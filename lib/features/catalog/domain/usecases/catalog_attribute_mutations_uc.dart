import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/catalog_repository.dart';

@lazySingleton
class CreateAttributeUC {
  final CatalogRepository repository;
  CreateAttributeUC(this.repository);
  Future<Either<Failure, Map<String, dynamic>>> call(String name) async {
    return await repository.createAttribute(name);
  }
}

@lazySingleton
class UpdateAttributeUC {
  final CatalogRepository repository;
  UpdateAttributeUC(this.repository);
  Future<Either<Failure, void>> call(String id, String name) async {
    return await repository.updateAttribute(id, name);
  }
}

@lazySingleton
class DeleteAttributeUC {
  final CatalogRepository repository;
  DeleteAttributeUC(this.repository);
  Future<Either<Failure, void>> call(String id) async {
    return await repository.deleteAttribute(id);
  }
}

@lazySingleton
class CreateAttributeValueUC {
  final CatalogRepository repository;
  CreateAttributeValueUC(this.repository);
  Future<Either<Failure, Map<String, dynamic>>> call(String attributeId, String value) async {
    return await repository.createAttributeValue(attributeId, value);
  }
}

@lazySingleton
class UpdateAttributeValueUC {
  final CatalogRepository repository;
  UpdateAttributeValueUC(this.repository);
  Future<Either<Failure, void>> call(String valueId, String value) async {
    return await repository.updateAttributeValue(valueId, value);
  }
}

@lazySingleton
class DeleteAttributeValueUC {
  final CatalogRepository repository;
  DeleteAttributeValueUC(this.repository);
  Future<Either<Failure, void>> call(String valueId) async {
    return await repository.deleteAttributeValue(valueId);
  }
}
