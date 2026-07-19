import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/get_default_address_uc.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/process_checkout_uc.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/send_whatsapp_order_uc.dart';
import 'package:inventory_store_app/features/orders/domain/usecases/verify_stock_uc.dart';
import 'package:inventory_store_app/features/orders/presentation/bloc/checkout_state.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/pos/presentation/bloc/cart/cart_cubit.dart';

@injectable
class CheckoutCubit extends Cubit<CheckoutState> {
  final GetDefaultAddressUc getDefaultAddressUc;
  final VerifyStockUc verifyStockUc;
  final ProcessCheckoutUc processCheckoutUc;
  final SendWhatsAppOrderUc sendWhatsAppOrderUc;

  CheckoutCubit({
    required this.getDefaultAddressUc,
    required this.verifyStockUc,
    required this.processCheckoutUc,
    required this.sendWhatsAppOrderUc,
  }) : super(const CheckoutState());

  // ── Toggle puntos ──────────────────────────────────────────────────────────

  void toggleUsePoints() {
    emit(state.copyWith(usePoints: !state.usePoints));
  }

  // ── Dirección por defecto ──────────────────────────────────────────────────

  Future<void> loadAddress(String profileId) async {
    emit(state.copyWith(isLoadingAddress: true));

    if (profileId.isEmpty) {
      emit(state.copyWith(isLoadingAddress: false, clearAddress: true));
      return;
    }

    final result = await getDefaultAddressUc(profileId);

    result.fold(
      (failure) => emit(
        state.copyWith(
          isLoadingAddress: false,
          status: CheckoutStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (address) => emit(
        state.copyWith(isLoadingAddress: false, defaultAddress: address),
      ),
    );
  }

  // ── Cálculos de descuento por puntos ───────────────────────────────────────

  double wholesalePriceOf(CartItemEntity item) {
    return item.wholesalePrice ?? item.unitPrice;
  }

  double maxDiscountSoles(CartCubit cartCubit) {
    double total = 0;
    for (final item in cartCubit.state.selectedItems) {
      final discount = item.unitPrice - wholesalePriceOf(item);
      if (discount > 0) total += discount * item.quantity;
    }
    return total;
  }

  int calculateApplicablePoints(
    CartCubit cartCubit,
    double pointsToSolesRatio,
    int saldoPuntos,
  ) {
    if (!state.usePoints) return 0;
    final maxSoles = maxDiscountSoles(cartCubit);
    final neededPoints = (maxSoles / pointsToSolesRatio).ceil();
    return saldoPuntos >= neededPoints ? neededPoints : saldoPuntos;
  }

  double calculateFinalTotal(
    CartCubit cartCubit,
    double pointsToSolesRatio,
    int saldoPuntos,
  ) {
    final discountSoles =
        calculateApplicablePoints(cartCubit, pointsToSolesRatio, saldoPuntos) *
        pointsToSolesRatio;
    return cartCubit.state.selectedTotalAmount - discountSoles;
  }

  int getAppliedPointsForItem(
    CartItemEntity item,
    CartCubit cartCubit,
    double pointsToSolesRatio,
    int saldoPuntos,
  ) {
    if (!state.usePoints || !item.isSelected) return 0;
    final discount = item.unitPrice - wholesalePriceOf(item);
    if (discount <= 0) return 0;

    final usedPoints = calculateApplicablePoints(
      cartCubit,
      pointsToSolesRatio,
      saldoPuntos,
    );
    if (usedPoints <= 0) return 0;

    final totalDiscount = maxDiscountSoles(cartCubit);
    if (totalDiscount <= 0) return 0;

    final proportion = (discount * item.quantity) / totalDiscount;
    return (usedPoints * proportion).round();
  }

  // ── Verificación de stock ──────────────────────────────────────────────────

  Future<List<String>> _verifyStock(
    List<CartItemEntity> itemsToBuy,
    CartCubit cartCubit,
  ) async {
    emit(state.copyWith(status: CheckoutStatus.verifyingStock));
    final List<String> outOfStockMessages = [];

    final variantIds =
        itemsToBuy
            .map((i) => i.variantId)
            .whereType<String>()
            .toList();

    final result = await verifyStockUc(variantIds);

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            status: CheckoutStatus.failure,
            errorMessage: failure.message,
          ),
        );
        outOfStockMessages.add(
          'Error al verificar stock: ${failure.message}',
        );
      },
      (stockMap) {
        for (final item in itemsToBuy) {
          if (item.variantId == null) continue;
          final currentStock = stockMap[item.variantId] ?? 0;
          cartCubit.updateAvailableStock(item.cartKey, currentStock);

          if (currentStock < item.quantity) {
            final variant =
                item.variantLabel != null ? ' - ${item.variantLabel}' : '';
            outOfStockMessages.add(
              '• ${item.productName}$variant (Disponible: $currentStock, Pedido: ${item.quantity})',
            );
          }
        }
        emit(state.copyWith(status: CheckoutStatus.idle));
      },
    );

    return outOfStockMessages;
  }

  // ── Submit del pedido ──────────────────────────────────────────────────────

  Future<void> submitOrder({
    required List<CartItemEntity> itemsToBuy,
    required CartCubit cartCubit,
    required String? profileId,
    required double pointsToSolesRatio,
    required int conversionRate,
    required int saldoPuntos,
    required String? activeWarehouseId,
    required String whatsappNumber,
  }) async {
    if (state.isSending || state.isVerifyingStock) return;

    // 1. Verificar stock
    final outOfStockMessages = await _verifyStock(itemsToBuy, cartCubit);
    if (outOfStockMessages.isNotEmpty) {
      emit(
        state.copyWith(
          status: CheckoutStatus.stockError,
          stockMessages: outOfStockMessages,
        ),
      );
      return;
    }

    // 2. Calcular totales
    emit(state.copyWith(status: CheckoutStatus.sending));

    final totalAmount = cartCubit.state.selectedTotalAmount;
    final usedPoints = calculateApplicablePoints(
      cartCubit,
      pointsToSolesRatio,
      saldoPuntos,
    );
    final discountAmount = usedPoints * pointsToSolesRatio;
    final totalAPagar = totalAmount - discountAmount;
    final pointsEarned = conversionRate > 0
        ? (totalAPagar / conversionRate).floor()
        : 0;

    double totalProfit = 0;
    for (final item in itemsToBuy) {
      double profitPerUnit = item.unitPrice - item.unitCost;
      final usedPts = getAppliedPointsForItem(
        item,
        cartCubit,
        pointsToSolesRatio,
        saldoPuntos,
      );
      profitPerUnit -= (usedPts * pointsToSolesRatio) / item.quantity;
      totalProfit += profitPerUnit * item.quantity;
    }

    // 3. Registrar en base de datos
    final result = await processCheckoutUc(
      customerId: profileId,
      totalAmount: totalAPagar,
      pointsUsed: usedPoints,
      pointsEarned: pointsEarned,
      totalProfit: totalProfit,
      warehouseId: activeWarehouseId,
      itemsToBuy: itemsToBuy,
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: CheckoutStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (orderId) async {
        // 4. Limpiar carrito
        cartCubit.removeSelected();

        // 5. Enviar por WhatsApp (dentro del Cubit, no en la UI)
        await sendWhatsAppOrderUc(
          whatsappNumber: whatsappNumber,
          items: itemsToBuy,
          orderId: orderId.substring(0, 8).toUpperCase(),
          totalAPagar: totalAPagar,
          puntosUsados: usedPoints,
        );

        // 6. Emitir éxito con payload tipado
        emit(
          state.copyWith(
            status: CheckoutStatus.success,
            successPayload: CheckoutSuccessPayload(
              orderId: orderId,
              totalAPagar: totalAPagar,
              puntosUsados: usedPoints,
              itemsBought: itemsToBuy,
            ),
          ),
        );
      },
    );
  }

  /// Restablece el estado a idle tras procesar el resultado en la UI.
  void resetStatus() {
    emit(state.copyWith(status: CheckoutStatus.idle));
  }
}
