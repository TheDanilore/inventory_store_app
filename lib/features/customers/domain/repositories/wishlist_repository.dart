import 'package:inventory_store_app/features/customers/domain/entities/wishlist_entry_entity.dart';

abstract class WishlistRepository {
  Future<List<WishlistEntryEntity>> getWishlist({
    required String profileId,
    required int limit,
    required int offset,
  });

  Future<void> removeFromWishlist({
    required String profileId,
    required String productId,
  });
}
