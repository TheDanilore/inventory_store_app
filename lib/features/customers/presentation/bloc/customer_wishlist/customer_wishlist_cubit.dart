import 'dart:developer' as developer;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/usecases/get_current_profile_id_usecase.dart';
import 'package:inventory_store_app/features/customers/domain/usecases/wishlist_ucs.dart';
import 'package:inventory_store_app/features/customers/domain/entities/wishlist_entry_entity.dart';
import 'package:inventory_store_app/features/customers/presentation/bloc/customer_wishlist/customer_wishlist_state.dart';

@injectable
class CustomerWishlistCubit extends Cubit<CustomerWishlistState> {
  final GetCurrentProfileIdUseCase _getCurrentProfileIdUseCase;
  final GetWishlistUseCase _getWishlistUseCase;
  final RemoveFromWishlistUseCase _removeFromWishlistUseCase;

  static const int _limit = 15;
  bool _isFetching = false;

  CustomerWishlistCubit(
    this._getCurrentProfileIdUseCase,
    this._getWishlistUseCase,
    this._removeFromWishlistUseCase,
  ) : super(CustomerWishlistInitial());

  Future<void> fetchWishlist({bool reset = false}) async {
    if (_isFetching) return;

    final profileIdResult = await _getCurrentProfileIdUseCase();
    final profileId = profileIdResult.fold((l) => null, (r) => r);

    if (profileId == null) {
      emit(const CustomerWishlistError('Usuario no autenticado'));
      return;
    }
    final currentState = state;
    var currentItems = <WishlistEntryEntity>[];

    if (currentState is CustomerWishlistLoaded) {
      currentItems = currentState.items;
      if (!reset && currentState.hasReachedMax) return;
    }

    _isFetching = true;

    if (reset) {
      currentItems = [];
      emit(CustomerWishlistLoading());
    }

    try {
      final fetched = await _getWishlistUseCase(
        profileId: profileId,
        limit: _limit,
        offset: currentItems.length,
      );

      emit(
        CustomerWishlistLoaded(
          items: reset ? fetched : [...currentItems, ...fetched],
          hasReachedMax: fetched.length < _limit,
        ),
      );
    } catch (e, st) {
      developer.log(
        'Error al obtener la lista de deseos',
        error: e,
        stackTrace: st,
        name: 'WishlistCubit',
      );
      emit(CustomerWishlistError(Failure.from(e).message));
    } finally {
      _isFetching = false;
    }
  }

  Future<void> removeFromWishlist(WishlistEntryEntity entry) async {
    final profileIdResult = await _getCurrentProfileIdUseCase();
    final profileId = profileIdResult.fold((l) => null, (r) => r);

    if (profileId == null) {
      emit(
        const CustomerWishlistError(
          'Usuario no autenticado para realizar esta acción',
        ),
      );
      return;
    }

    final currentState = state;
    if (currentState is CustomerWishlistLoaded) {
      if (currentState.removingIds.contains(entry.wishlistId)) return;

      final newRemovingIds = Set<String>.from(currentState.removingIds)
        ..add(entry.wishlistId);
      emit(currentState.copyWith(removingIds: newRemovingIds));

      try {
        await _removeFromWishlistUseCase(
          profileId: profileId,
          productId: entry.product.id,
        );
        final updated =
            currentState.items
                .where((i) => i.wishlistId != entry.wishlistId)
                .toList();
        final afterRemovingIds = Set<String>.from(newRemovingIds)
          ..remove(entry.wishlistId);
        emit(
          currentState.copyWith(items: updated, removingIds: afterRemovingIds),
        );
      } catch (e, st) {
        developer.log(
          'Error crítico al eliminar ítem de lista de deseos',
          error: e,
          stackTrace: st,
          name: 'WishlistCubit',
        );
        final afterRemovingIds = Set<String>.from(newRemovingIds)
          ..remove(entry.wishlistId);
        emit(CustomerWishlistError(Failure.from(e).message));
        emit(currentState.copyWith(removingIds: afterRemovingIds));
      }
    }
  }
}
