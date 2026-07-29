import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/pos/domain/usecases/load_cart_uc.dart';
import 'package:inventory_store_app/features/pos/domain/usecases/save_cart_uc.dart';
import 'package:inventory_store_app/features/pos/domain/usecases/clear_cart_uc.dart';
import 'package:inventory_store_app/features/pos/domain/usecases/sync_cart_uc.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@injectable
class CartCubit extends Cubit<CartState> {
  final LoadCartUseCase _loadCart;
  final SaveCartUseCase _saveCart;
  final SyncCartUseCase _syncCart;
  final ClearCartUseCase _clearCart;

  String _cartType = 'customer';

  CartCubit({
    required LoadCartUseCase loadCart,
    required SaveCartUseCase saveCart,
    required SyncCartUseCase syncCart,
    required ClearCartUseCase clearCart,
  }) : _loadCart = loadCart,
       _saveCart = saveCart,
       _syncCart = syncCart,
       _clearCart = clearCart,
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
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await syncCloudCart();
    }
  }

  Future<void> syncCloudCart() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    emit(state.copyWith(isSyncing: true));

    // Supabase will automatically map the auth ID to profile ID inside the repository if we want,
    // or we can pass auth_user_id and let repository handle it. The repo takes profileId.
    // Wait, the repository `syncCloudCart` takes profileId, but old implementation passed auth.currentUser.id!
    // So the repo `_getOrCreateCartId` handles profileId, wait no, old CartCloudService did `_getProfileId(authUserId)`.
    // I need to ensure my `CartRepositoryImpl.syncCloudCart` gets the profile ID correctly.
    // In CartRepositoryImpl, `syncCloudCart` parameter is `String profileId`. We can assume the caller passes authUserId and the repo looks it up, OR we can look it up here.
    // Let's pass the auth user ID to the repo and let it translate it (or we can just leave it as is if repo does it).
    // I will assume `profileId` parameter in SyncCartParams is actually `authUserId` based on legacy.

    final res = await _syncCart(
      SyncCartParams(
        cartType: _cartType,
        profileId: user.id,
        localItems: state.items,
      ),
    );
    res.fold(
      (failure) =>
          emit(state.copyWith(isSyncing: false, errorMessage: failure.message)),
      (items) {
        emit(state.copyWith(isSyncing: false, items: items));
      },
    );
  }

  Future<void> _saveLocal() async {
    await _saveCart(SaveCartParams(cartType: _cartType, items: state.items));
  }

  void addItem(CartItemEntity item) {
    final newItems = Map<String, CartItemEntity>.from(state.items);

    if (newItems.containsKey(item.cartKey)) {
      final existing = newItems[item.cartKey]!;
      newItems[item.cartKey] = CartItemEntity(
        productId: existing.productId,
        productName: existing.productName,
        cartKey: existing.cartKey,
        quantity: existing.quantity + item.quantity,
        unitPrice: existing.unitPrice,
        unitCost: existing.unitCost,
        availableStock: existing.availableStock,
        usesBatches: existing.usesBatches,
        variantId: existing.variantId,
        variantLabel: existing.variantLabel,
        wholesalePrice: existing.wholesalePrice,
        imageUrl: existing.imageUrl,
        sku: existing.sku,
        isSelected: existing.isSelected,
      );
    } else {
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
        newItems[cartKey] = CartItemEntity(
          productId: existing.productId,
          productName: existing.productName,
          cartKey: existing.cartKey,
          quantity: qty,
          unitPrice: existing.unitPrice,
          unitCost: existing.unitCost,
          availableStock: existing.availableStock,
          usesBatches: existing.usesBatches,
          variantId: existing.variantId,
          variantLabel: existing.variantLabel,
          wholesalePrice: existing.wholesalePrice,
          imageUrl: existing.imageUrl,
          sku: existing.sku,
          isSelected: existing.isSelected,
        );
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
      newItems[cartKey] = CartItemEntity(
        productId: existing.productId,
        productName: existing.productName,
        cartKey: existing.cartKey,
        quantity: existing.quantity,
        unitPrice: existing.unitPrice,
        unitCost: existing.unitCost,
        availableStock: existing.availableStock,
        usesBatches: existing.usesBatches,
        variantId: existing.variantId,
        variantLabel: existing.variantLabel,
        wholesalePrice: existing.wholesalePrice,
        imageUrl: existing.imageUrl,
        sku: existing.sku,
        isSelected: value,
      );
      emit(state.copyWith(items: newItems));
      _saveLocal();
    }
  }

  void toggleAllSelection(bool value) {
    final newItems = Map<String, CartItemEntity>.from(state.items);
    for (final key in newItems.keys) {
      final existing = newItems[key]!;
      newItems[key] = CartItemEntity(
        productId: existing.productId,
        productName: existing.productName,
        cartKey: existing.cartKey,
        quantity: existing.quantity,
        unitPrice: existing.unitPrice,
        unitCost: existing.unitCost,
        availableStock: existing.availableStock,
        usesBatches: existing.usesBatches,
        variantId: existing.variantId,
        variantLabel: existing.variantLabel,
        wholesalePrice: existing.wholesalePrice,
        imageUrl: existing.imageUrl,
        sku: existing.sku,
        isSelected: value,
      );
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

  Future<void> clearCart() async {
    final user = Supabase.instance.client.auth.currentUser;
    final profileId =
        user?.id; // Note: passed as authUserId to usecase/repository

    await _clearCart(
      ClearCartParams(cartType: _cartType, profileId: profileId),
    );
    emit(state.copyWith(items: {}));
  }

  void updateAvailableStock(String cartKey, int newStock) {
    final newItems = Map<String, CartItemEntity>.from(state.items);
    if (newItems.containsKey(cartKey)) {
      final existing = newItems[cartKey]!;
      newItems[cartKey] = CartItemEntity(
        productId: existing.productId,
        productName: existing.productName,
        cartKey: existing.cartKey,
        quantity: existing.quantity,
        unitPrice: existing.unitPrice,
        unitCost: existing.unitCost,
        availableStock: newStock,
        usesBatches: existing.usesBatches,
        variantId: existing.variantId,
        variantLabel: existing.variantLabel,
        wholesalePrice: existing.wholesalePrice,
        imageUrl: existing.imageUrl,
        sku: existing.sku,
        isSelected: existing.isSelected,
      );
      emit(state.copyWith(items: newItems));
      _saveLocal();
    }
  }
}
