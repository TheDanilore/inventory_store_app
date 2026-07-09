import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/catalog_repository.dart';

@lazySingleton
class GetCurrentProfileIdUseCase {
  final CatalogRepository repository;

  GetCurrentProfileIdUseCase(this.repository);

  Future<Either<Failure, String?>> call() {
    return repository.fetchCurrentProfileId();
  }
}
