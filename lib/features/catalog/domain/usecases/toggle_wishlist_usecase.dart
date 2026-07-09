import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/catalog_repository.dart';

@lazySingleton
class ToggleWishlistUseCase {
  final CatalogRepository repository;

  ToggleWishlistUseCase(this.repository);

  Future<Either<Failure, bool>> call({required String productId, required String profileId, required bool currentStatus}) {
    return repository.toggleWishlist(productId, profileId, currentStatus);
  }
}
