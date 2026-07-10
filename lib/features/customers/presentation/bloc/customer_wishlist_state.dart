import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/catalog/data/models/product_model.dart';

class WishlistEntryModel extends Equatable {
  final String wishlistId;
  final DateTime? createdAt;
  final ProductModel product;

  const WishlistEntryModel({
    required this.wishlistId,
    required this.createdAt,
    required this.product,
  });

  @override
  List<Object?> get props => [wishlistId, createdAt, product];
}

abstract class CustomerWishlistState extends Equatable {
  const CustomerWishlistState();

  @override
  List<Object?> get props => [];
}

class CustomerWishlistInitial extends CustomerWishlistState {}

class CustomerWishlistLoading extends CustomerWishlistState {}

class CustomerWishlistLoaded extends CustomerWishlistState {
  final List<WishlistEntryModel> items;
  final bool hasReachedMax;

  const CustomerWishlistLoaded({
    required this.items,
    required this.hasReachedMax,
  });

  CustomerWishlistLoaded copyWith({
    List<WishlistEntryModel>? items,
    bool? hasReachedMax,
  }) {
    return CustomerWishlistLoaded(
      items: items ?? this.items,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }

  @override
  List<Object?> get props => [items, hasReachedMax];
}

class CustomerWishlistError extends CustomerWishlistState {
  final String message;

  const CustomerWishlistError(this.message);

  @override
  List<Object?> get props => [message];
}
