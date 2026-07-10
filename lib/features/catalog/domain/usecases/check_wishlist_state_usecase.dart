import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/catalog_repository.dart';

@lazySingleton
class CheckWishlistStateUseCase {
  final CatalogRepository repository;

  CheckWishlistStateUseCase(this.repository);

  Future<Either<Failure, bool>> call({
    required String productId,
    required String profileId,
  }) {
    return repository.checkWishlistState(productId, profileId);
  }
}
