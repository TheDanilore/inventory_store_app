import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/checkout_state.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_cubit.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/get_default_address_uc.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/verify_stock_uc.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/process_checkout_uc.dart';

import 'package:injectable/injectable.dart';

@injectable
class CheckoutCubit extends Cubit<CheckoutState> {
  final GetDefaultAddressUc getDefaultAddressUc;
  final VerifyStockUc verifyStockUc;
  final ProcessCheckoutUc processCheckoutUc;

  CheckoutCubit({
    required this.getDefaultAddressUc,
    required this.verifyStockUc,
    required this.processCheckoutUc,
  }) : super(const CheckoutState());

  void toggleUsePoints() {
    emit(state.copyWith(usePoints: !state.usePoints));
  }

  Future<void> loadAddress(String profileId) async {
    emit(state.copyWith(isLoadingAddress: true));
    
    final result = await getDefaultAddressUc(profileId);
    
    result.fold(
      (failure) => emit(state.copyWith(isLoadingAddress: false, errorMessage: failure.message)),
      (address) => emit(state.copyWith(isLoadingAddress: false, defaultAddress: address)),
    );
  }

  double wholesalePriceOf(CartItemEntity item) {
    return item.wholesalePrice ?? item.unitPrice;
  }

  double maxDiscountSoles(CartCubit cartCubit) {
    double total = 0;
    for (final item in cartCubit.state.selectedItems) {
      final wPrice = wholesalePriceOf(item);
      final discountPerItem = item.unitPrice - wPrice;
      if (discountPerItem > 0) {
        total += discountPerItem * item.quantity;
      }
    }
    return total;
  }

  int calculateApplicablePoints(CartCubit cartCubit, double pointsToSolesRatio, int saldoPuntos) {
    if (!state.usePoints) return 0;
    final maxSoles = maxDiscountSoles(cartCubit);
    final neededPoints = (maxSoles / pointsToSolesRatio).ceil();
    return saldoPuntos >= neededPoints ? neededPoints : saldoPuntos;
  }

  double calculateFinalTotal(CartCubit cartCubit, double pointsToSolesRatio, int saldoPuntos) {
    final discountSoles = calculateApplicablePoints(cartCubit, pointsToSolesRatio, saldoPuntos) * pointsToSolesRatio;
    return cartCubit.state.selectedTotalAmount - discountSoles;
  }

  int getAppliedPointsForItem(CartItemEntity item, CartCubit cartCubit, double pointsToSolesRatio, int saldoPuntos) {
    if (!state.usePoints) return 0;
    if (!item.isSelected) return 0;
    final wPrice = wholesalePriceOf(item);
    final discountPerItemSoles = item.unitPrice - wPrice;
    if (discountPerItemSoles <= 0) return 0;

    final usedPoints = calculateApplicablePoints(cartCubit, pointsToSolesRatio, saldoPuntos);
    if (usedPoints <= 0) return 0;

    final totalDiscountPossible = maxDiscountSoles(cartCubit);
    if (totalDiscountPossible <= 0) return 0;

    final itemDiscountTotal = discountPerItemSoles * item.quantity;
    final proportion = itemDiscountTotal / totalDiscountPossible;
    return (usedPoints * proportion).round();
  }

  Future<List<String>> _verifyStock(List<CartItemEntity> itemsToBuy, CartCubit cartCubit) async {
    emit(state.copyWith(isVerifyingStock: true));
    List<String> outOfStockMessages = [];

    final variantIds = itemsToBuy.map((i) => i.variantId).where((id) => id != null).cast<String>().toList();
    
    final result = await verifyStockUc(variantIds);
    
    result.fold(
      (failure) {
        emit(state.copyWith(isVerifyingStock: false, errorMessage: failure.message));
      },
      (stockMap) {
        for (final item in itemsToBuy) {
          if (item.variantId == null) continue;
          final currentStock = stockMap[item.variantId] ?? 0;
          cartCubit.updateAvailableStock(item.cartKey, currentStock);
          
          if (currentStock < item.quantity) {
            final variantLabel = item.variantLabel != null ? ' - ${item.variantLabel}' : '';
            outOfStockMessages.add('• ${item.productName}$variantLabel (Stock disponible: $currentStock, Tu pedido: ${item.quantity})');
          }
        }
        emit(state.copyWith(isVerifyingStock: false));
      }
    );

    return outOfStockMessages;
  }

  Future<Map<String, dynamic>?> submitOrder({
    required List<CartItemEntity> itemsToBuy,
    required CartCubit cartCubit,
    required String? profileId,
    required double pointsToSolesRatio,
    required int conversionRate,
    required int saldoPuntos,
    required String? activeWarehouseId,
  }) async {
    if (state.isSending) return null;
    
    final outOfStockMessages = await _verifyStock(itemsToBuy, cartCubit);
    if (outOfStockMessages.isNotEmpty) {
      emit(state.copyWith(
        errorMessage: 'STOCK',
        successData: {'messages': outOfStockMessages}
      ));
      return {'error': 'STOCK', 'messages': outOfStockMessages};
    }

    emit(state.copyWith(isSending: true));

    final totalAmount = cartCubit.state.selectedTotalAmount;
    final usedPoints = calculateApplicablePoints(cartCubit, pointsToSolesRatio, saldoPuntos);
    final discountAmount = usedPoints * pointsToSolesRatio;
    final totalAPagar = totalAmount - discountAmount;
    final pointsEarned = (totalAPagar / conversionRate).floor();

    double totalProfit = 0;
    for (var item in itemsToBuy) {
      double profitPerUnit = item.unitPrice - item.unitCost;
      final usedPts = getAppliedPointsForItem(item, cartCubit, pointsToSolesRatio, saldoPuntos);
      profitPerUnit -= (usedPts * pointsToSolesRatio) / item.quantity;
      totalProfit += profitPerUnit * item.quantity;
    }

    final result = await processCheckoutUc(
      customerId: profileId,
      totalAmount: totalAPagar,
      pointsUsed: usedPoints,
      pointsEarned: pointsEarned,
      totalProfit: totalProfit,
      warehouseId: activeWarehouseId,
      itemsToBuy: itemsToBuy,
    );

    return result.fold(
      (failure) {
        emit(state.copyWith(isSending: false, errorMessage: failure.message));
        return {'error': true, 'message': failure.message};
      },
      (orderId) {
        cartCubit.removeSelected();
        final successMap = {
          'success': true,
          'orderId': orderId,
          'itemsToBuy': itemsToBuy,
          'totalAPagar': totalAPagar,
          'puntosUsados': usedPoints,
        };
        emit(state.copyWith(
          isSending: false, 
          successData: successMap,
        ));
        return successMap;
      }
    );
  }
}
