import 'package:inventory_store_app/features/pos/presentation/bloc/pos/pos_state.dart';
import 'package:inventory_store_app/features/cart/presentation/bloc/cart_state.dart';

class PosCalculatorUtils {
  static int clampPointsValue(
    int desired,
    PosState pos,
    CartState cart,
    double ratio,
  ) {
    if (pos.selectedClientId == null) return 0;
    if (pos.saldoActualCliente <= 0) return 0;

    int maxPts = pos.saldoActualCliente;
    final total = cart.totalAmount;
    final maxPtsForTotal = (total / ratio).floor();

    if (maxPts > maxPtsForTotal) maxPts = maxPtsForTotal;
    if (desired > maxPts) return maxPts;
    if (desired < 0) return 0;

    return desired;
  }

  static int maxPuntosAplicables(PosState pos, CartState cart, double ratio) {
    if (pos.selectedClientId == null) return 0;
    if (pos.saldoActualCliente <= 0) return 0;

    final total = cart.totalAmount;
    final maxPtsForTotal = (total / ratio).floor();

    return pos.saldoActualCliente > maxPtsForTotal
        ? maxPtsForTotal
        : pos.saldoActualCliente;
  }

  static double getCustomDiscountAmount({
    required String discountText,
    required bool isDiscountPercentage,
    required PosState pos,
    required CartState cart,
    required double ratio,
  }) {
    final raw = double.tryParse(discountText) ?? 0.0;
    if (raw <= 0) return 0.0;

    if (isDiscountPercentage) {
      final safePts = clampPointsValue(pos.puntosAUsar, pos, cart, ratio);
      final partial = cart.totalAmount - (safePts * ratio);
      return partial * (raw / 100).clamp(0.0, 1.0);
    }

    return raw;
  }

  static double calcularTotalFinal({
    required String discountText,
    required bool isDiscountPercentage,
    required PosState pos,
    required CartState cart,
    required double ratio,
  }) {
    final safePts = clampPointsValue(pos.puntosAUsar, pos, cart, ratio);
    final discExtra = getCustomDiscountAmount(
      discountText: discountText,
      isDiscountPercentage: isDiscountPercentage,
      pos: pos,
      cart: cart,
      ratio: ratio,
    );

    final partial = cart.totalAmount - (safePts * ratio) - discExtra;
    return partial < 0 ? 0 : partial;
  }

  static double calcularGananciaTotal({
    required String discountText,
    required bool isDiscountPercentage,
    required PosState pos,
    required CartState cart,
    required double ratio,
  }) {
    double totalNetProfit = 0;
    for (final item in cart.items.values) {
      totalNetProfit += (item.unitPrice - item.unitCost) * item.quantity;
    }

    final safePts = clampPointsValue(pos.puntosAUsar, pos, cart, ratio);
    final totalDesc =
        (safePts * ratio) +
        getCustomDiscountAmount(
          discountText: discountText,
          isDiscountPercentage: isDiscountPercentage,
          pos: pos,
          cart: cart,
          ratio: ratio,
        );

    return totalNetProfit - totalDesc;
  }

  static bool isCreditActivo(Map<String, dynamic>? creditInfo) {
    return creditInfo != null && creditInfo['is_active'] == true;
  }

  static double getCreditDisponible(Map<String, dynamic>? creditInfo) {
    if (!isCreditActivo(creditInfo)) return 0.0;
    final limit = (creditInfo!['credit_limit'] as num).toDouble();
    final debt = (creditInfo['current_debt'] as num).toDouble();
    final disp = limit - debt;
    return disp > 0 ? disp : 0;
  }

  static double getMaxCustomDiscount(
    CartState cart,
    double ratio,
    int puntosSeguros,
  ) {
    return cart.totalAmount - (puntosSeguros * ratio);
  }

  static int calcularPuntosGanados({
    required double total,
    required double rate,
  }) {
    return (total * rate).floor();
  }

  static bool accountRequiresShift(Map<String, dynamic>? accountData) {
    if (accountData == null || accountData.isEmpty) return false;
    if (accountData['is_cash_register'] == true ||
        accountData['requires_shift'] == true) {
      return true;
    }
    final accountType = accountData['type']?.toString().toUpperCase() ?? '';
    return accountType == 'CAJA' || accountType == 'CASH_REGISTER';
  }

  static String? validateSalePreFlight({
    required PosState posState,
    required CartState cartState,
    required double totalFinal,
    bool isDraft = false,
  }) {
    if (posState.selectedWarehouseId == null) {
      return 'Selecciona un almacén para continuar.';
    }
    if (cartState.items.isEmpty) {
      return 'La caja está vacía.';
    }

    if (!isDraft) {
      final hasNoStockItem = cartState.items.values.any(
        (i) => i.availableStock <= 0,
      );
      if (hasNoStockItem) {
        return 'Hay productos sin stock en la tienda/almacén seleccionado.';
      }
    }

    final isCredito = posState.paymentMethod == 'CRÉDITO';

    if (!isDraft && !isCredito) {
      if (posState.selectedAccountId == null) {
        return 'Selecciona una cuenta financiera para el ingreso.';
      }
      final accountData = posState.accounts.firstWhere(
        (a) => a['id'] == posState.selectedAccountId,
        orElse: () => <String, dynamic>{},
      );
      if (accountRequiresShift(accountData) && posState.activeShift == null) {
        return 'La cuenta seleccionada requiere un turno abierto.';
      }
    }

    if (isCredito && !isDraft) {
      if (posState.selectedClientId == null) {
        return 'Debes seleccionar un cliente para ventas a crédito.';
      }
      if (!isCreditActivo(posState.creditInfo)) {
        return 'El cliente no tiene línea de crédito activa.';
      }
      final disp = getCreditDisponible(posState.creditInfo);
      if (disp < totalFinal) {
        return 'Crédito insuficiente. Disponible: S/ ${disp.toStringAsFixed(2)}';
      }
    }

    return null; // Validación exitosa
  }
}
