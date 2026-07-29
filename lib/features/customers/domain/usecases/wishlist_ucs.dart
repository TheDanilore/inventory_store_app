import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/wishlist_entry_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/wishlist_repository.dart';

@lazySingleton
class GetWishlistUseCase {
  final WishlistRepository _repository;

  GetWishlistUseCase(this._repository);

  Future<List<WishlistEntryEntity>> call({
    required String profileId,
    required int limit,
    required int offset,
  }) {
    return _repository.getWishlist(
      profileId: profileId,
      limit: limit,
      offset: offset,
    );
  }
}

@lazySingleton
class RemoveFromWishlistUseCase {
  final WishlistRepository _repository;

  RemoveFromWishlistUseCase(this._repository);

  Future<void> call({required String profileId, required String productId}) {
    return _repository.removeFromWishlist(
      profileId: profileId,
      productId: productId,
    );
  }
}
