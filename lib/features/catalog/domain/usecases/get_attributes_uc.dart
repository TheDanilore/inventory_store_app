import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/catalog_repository.dart';

@lazySingleton
class GetAttributesUC {
  final CatalogRepository repository;
  GetAttributesUC(this.repository);
  Future<Either<Failure, List<Map<String, dynamic>>>> call() async {
    return await repository.getAttributes();
  }
}
