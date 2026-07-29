import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/wishlist_entry_entity.dart';

abstract class CustomerWishlistState extends Equatable {
  const CustomerWishlistState();

  @override
  List<Object?> get props => [];
}

class CustomerWishlistInitial extends CustomerWishlistState {}

class CustomerWishlistLoading extends CustomerWishlistState {}

class CustomerWishlistLoaded extends CustomerWishlistState {
  final List<WishlistEntryEntity> items;
  final bool hasReachedMax;

  const CustomerWishlistLoaded({
    required this.items,
    required this.hasReachedMax,
  });

  CustomerWishlistLoaded copyWith({
    List<WishlistEntryEntity>? items,
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
