import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/catalog/domain/entities/product_entity.dart';

class WishlistEntryEntity extends Equatable {
  final String wishlistId;
  final DateTime? createdAt;
  final ProductEntity product;

  const WishlistEntryEntity({
    required this.wishlistId,
    required this.createdAt,
    required this.product,
  });

  @override
  List<Object?> get props => [wishlistId, createdAt, product];
}
