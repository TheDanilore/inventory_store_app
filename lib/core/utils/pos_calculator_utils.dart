import 'package:inventory_store_app/features/pos/presentation/providers/pos_provider.dart';

class PosCalculatorUtils {
  static int clampPointsValue(int desired, PosProvider pos, double ratio) {
    if (pos.selectedClientId == null) return 0;
    if (pos.saldoActualCliente <= 0) return 0;

    int maxPts = pos.saldoActualCliente;
    final total = pos.totalAmount;
    final maxPtsForTotal = (total / ratio).floor();

    if (maxPts > maxPtsForTotal) maxPts = maxPtsForTotal;
    if (desired > maxPts) return maxPts;
    if (desired < 0) return 0;

    return desired;
  }

  static int maxPuntosAplicables(PosProvider pos, double ratio) {
    if (pos.selectedClientId == null) return 0;
    if (pos.saldoActualCliente <= 0) return 0;

    final total = pos.totalAmount;
    final maxPtsForTotal = (total / ratio).floor();

    return pos.saldoActualCliente > maxPtsForTotal
        ? maxPtsForTotal
        : pos.saldoActualCliente;
  }

  static double getCustomDiscountAmount({
    required String discountText,
    required bool isDiscountPercentage,
    required PosProvider pos,
    required double ratio,
  }) {
    final raw = double.tryParse(discountText) ?? 0.0;
    if (raw <= 0) return 0.0;

    if (isDiscountPercentage) {
      final safePts = clampPointsValue(pos.puntosAUsar, pos, ratio);
      final partial = pos.totalAmount - (safePts * ratio);
      return partial * (raw / 100).clamp(0.0, 1.0);
    }

    return raw;
  }

  static double calcularTotalFinal({
    required String discountText,
    required bool isDiscountPercentage,
    required PosProvider pos,
    required double ratio,
  }) {
    final safePts = clampPointsValue(pos.puntosAUsar, pos, ratio);
    final discExtra = getCustomDiscountAmount(
      discountText: discountText,
      isDiscountPercentage: isDiscountPercentage,
      pos: pos,
      ratio: ratio,
    );

    final partial = pos.totalAmount - (safePts * ratio) - discExtra;
    return partial < 0 ? 0 : partial;
  }

  static double calcularGananciaTotal({
    required String discountText,
    required bool isDiscountPercentage,
    required PosProvider pos,
    required double ratio,
  }) {
    double totalNetProfit = 0;
    for (final item in pos.items.values) {
      totalNetProfit += (item.unitPrice - item.unitCost) * item.quantity;
    }

    final safePts = clampPointsValue(pos.puntosAUsar, pos, ratio);
    final totalDesc =
        (safePts * ratio) +
        getCustomDiscountAmount(
          discountText: discountText,
          isDiscountPercentage: isDiscountPercentage,
          pos: pos,
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

  static double getMaxCustomDiscount(PosProvider pos, double ratio, int puntosSeguros) {
    return pos.totalAmount - (puntosSeguros * ratio);
  }

  static int calcularPuntosGanados({required double total, required double rate}) {
    return (total * rate).floor();
  }
}
