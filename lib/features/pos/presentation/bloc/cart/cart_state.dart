import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';

class CartState extends Equatable {
  final Map<String, CartItemEntity> items;
  final bool isLoading;
  final bool isSyncing;
  final String? errorMessage;

  const CartState({
    this.items = const {},
    this.isLoading = false,
    this.isSyncing = false,
    this.errorMessage,
  });

  CartState copyWith({
    Map<String, CartItemEntity>? items,
    bool? isLoading,
    bool? isSyncing,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return CartState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isSyncing: isSyncing ?? this.isSyncing,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
    );
  }

  int get itemCount => items.length;

  List<CartItemEntity> get selectedItems =>
      items.values.where((item) => item.isSelected).toList();

  int get selectedItemCount => selectedItems.length;

  double get selectedTotalAmount {
    var total = 0.0;
    for (final item in selectedItems) {
      total += item.subtotal;
    }
    return total;
  }

  double get totalAmount {
    var total = 0.0;
    for (final item in items.values) {
      total += item.subtotal;
    }
    return total;
  }

  bool get isAllSelected =>
      items.isNotEmpty && items.values.every((item) => item.isSelected);

  @override
  List<Object?> get props => [
        items,
        isLoading,
        isSyncing,
        errorMessage,
      ];
}
