import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';

import 'package:inventory_store_app/features/catalog/domain/entities/attribute_entity.dart';

@lazySingleton
class GetAttributesUC {
  final ProductsRepository repository;
  GetAttributesUC(this.repository);
  Future<Either<Failure, List<AttributeEntity>>> call() async {
    return await repository.getAttributes();
  }
}
