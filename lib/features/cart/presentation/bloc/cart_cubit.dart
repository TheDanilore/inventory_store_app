import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/cart/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/cart/domain/usecases/load_cart_uc.dart';
import 'package:inventory_store_app/features/cart/domain/usecases/save_cart_uc.dart';
import 'package:inventory_store_app/features/cart/domain/usecases/clear_cart_uc.dart';
import 'package:inventory_store_app/features/cart/domain/usecases/sync_cart_uc.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/auth/domain/usecases/get_current_user_uc.dart';

@injectable
class CartCubit extends Cubit<CartState> {
  final LoadCartUseCase _loadCart;
  final SaveCartUseCase _saveCart;
  final SyncCartUseCase _syncCart;
  final ClearCartUseCase _clearCart;
  final GetCurrentUserUseCase _getCurrentUser;

  String _cartType = 'customer';

  CartCubit({
    required LoadCartUseCase loadCart,
    required SaveCartUseCase saveCart,
    required SyncCartUseCase syncCart,
    required ClearCartUseCase clearCart,
    required GetCurrentUserUseCase getCurrentUser,
  }) : _loadCart = loadCart,
       _saveCart = saveCart,
       _syncCart = syncCart,
       _clearCart = clearCart,
       _getCurrentUser = getCurrentUser,
       super(const CartState());

  void setCartType(String cartType) {
    _cartType = cartType;
  }

  Future<void> initCart({String cartType = 'customer'}) async {
    _cartType = cartType;
    emit(state.copyWith(isLoading: true));

    final localRes = await _loadCart(LoadCartParams(_cartType));
    localRes.fold(
      (failure) =>
          emit(state.copyWith(isLoading: false, errorMessage: failure.message)),
      (items) {
        emit(state.copyWith(isLoading: false, items: items));
      },
    );

    // Sync if user is authenticated (Note: auth check can be delegated or done here)
    // Actually, in Clean Architecture, we could pass the profile ID if known,
    // but we can let the caller trigger sync, or do a quick check here.
    final userRes = await _getCurrentUser(const NoParams());
    userRes.fold((_) => null, (user) async {
      await syncCloudCart(profileId: user.id);
    });
  }

  Future<void> syncCloudCart({String? profileId}) async {
    String? userId = profileId;
    if (userId == null) {
      final userRes = await _getCurrentUser(const NoParams());
      userId = userRes.fold((_) => null, (u) => u.id);
    }
    if (userId == null) return;

    emit(state.copyWith(isSyncing: true));

    final res = await _syncCart(
      SyncCartParams(
        cartType: _cartType,
        profileId: userId,
        localItems: state.items,
      ),
    );
    res.fold(
      (failure) =>
          emit(state.copyWith(isSyncing: false, errorMessage: failure.message)),
      (items) {
        emit(state.copyWith(isSyncing: false, items: items));
        _saveLocal(); // Convergencia de caché: persistir los datos descargados para coherencia offline
      },
    );
  }

  Future<void> _saveLocal() async {
    await _saveCart(SaveCartParams(cartType: _cartType, items: state.items));
  }

  void clearError() {
    emit(state.copyWith(clearErrorMessage: true));
  }

  void addItem(CartItemEntity item) {
    if (item.availableStock <= 0) {
      emit(state.copyWith(errorMessage: 'Producto agotado.'));
      return;
    }

    final newItems = Map<String, CartItemEntity>.from(state.items);

    if (newItems.containsKey(item.cartKey)) {
      final existing = newItems[item.cartKey]!;
      final newQty = existing.quantity + item.quantity;
      if (newQty > existing.availableStock) {
        emit(
          state.copyWith(
            errorMessage: 'Stock insuficiente para esta cantidad.',
          ),
        );
        return;
      }
      newItems[item.cartKey] = existing.copyWith(quantity: newQty);
    } else {
      if (item.quantity > item.availableStock) {
        emit(
          state.copyWith(
            errorMessage: 'Stock insuficiente para esta cantidad.',
          ),
        );
        return;
      }
      newItems[item.cartKey] = item;
    }

    emit(state.copyWith(items: newItems));
    _saveLocal();
  }

  void updateQuantity(String cartKey, int qty) {
    final newItems = Map<String, CartItemEntity>.from(state.items);
    if (newItems.containsKey(cartKey)) {
      if (qty <= 0) {
        newItems.remove(cartKey);
      } else {
        final existing = newItems[cartKey]!;
        if (qty > existing.availableStock) {
          emit(
            state.copyWith(
              errorMessage: 'Stock insuficiente para esta cantidad.',
            ),
          );
          return;
        }
        newItems[cartKey] = existing.copyWith(quantity: qty);
      }
      emit(state.copyWith(items: newItems));
      _saveLocal();
    }
  }

  void removeItem(String cartKey) {
    final newItems = Map<String, CartItemEntity>.from(state.items);
    if (newItems.containsKey(cartKey)) {
      newItems.remove(cartKey);
      emit(state.copyWith(items: newItems));
      _saveLocal();
    }
  }

  void toggleItemSelection(String cartKey, bool value) {
    final newItems = Map<String, CartItemEntity>.from(state.items);
    if (newItems.containsKey(cartKey)) {
      final existing = newItems[cartKey]!;
      newItems[cartKey] = existing.copyWith(isSelected: value);
      emit(state.copyWith(items: newItems));
      _saveLocal();
    }
  }

  void toggleAllSelection(bool value) {
    final newItems = Map<String, CartItemEntity>.from(state.items);
    for (final key in newItems.keys) {
      final existing = newItems[key]!;
      newItems[key] = existing.copyWith(isSelected: value);
    }
    emit(state.copyWith(items: newItems));
    _saveLocal();
  }

  void removeSelected() {
    final newItems = Map<String, CartItemEntity>.from(state.items);
    newItems.removeWhere((key, item) => item.isSelected);
    emit(state.copyWith(items: newItems));
    _saveLocal();
  }

  Future<void> clearCart({String? profileId}) async {
    String? userId = profileId;
    if (userId == null) {
      final userRes = await _getCurrentUser(const NoParams());
      userId = userRes.fold((_) => null, (u) => u.id);
    }

    final res = await _clearCart(
      ClearCartParams(cartType: _cartType, profileId: userId),
    );
    res.fold(
      (failure) => emit(state.copyWith(errorMessage: failure.message)),
      (_) => emit(state.copyWith(items: {}, clearErrorMessage: true)),
    );
  }

  void updateAvailableStock(String cartKey, int newStock) {
    final newItems = Map<String, CartItemEntity>.from(state.items);
    if (newItems.containsKey(cartKey)) {
      final existing = newItems[cartKey]!;
      newItems[cartKey] = existing.copyWith(availableStock: newStock);
      emit(state.copyWith(items: newItems));
      _saveLocal();
    }
  }
}
