import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';

/// Helper inmutable para cálculos tributarios y desglose de comprobantes (SUNAT).
/// Evita duplicación de lógica y desfasajes por redondeo entre vistas y exportadores.
class ReceiptTaxHelper {
  final double opGravada;
  final double igvAmount;
  final double totalAmount;
  final double discountAmount;
  final int pointsUsed;

  const ReceiptTaxHelper._({
    required this.opGravada,
    required this.igvAmount,
    required this.totalAmount,
    required this.discountAmount,
    required this.pointsUsed,
  });

  factory ReceiptTaxHelper.fromOrder(OrderEntity order) {
    final total = order.totalAmount;
    final subtotal = order.subtotalAmount;
    final tax = order.taxAmount;

    final gravada =
        subtotal > 0
            ? subtotal
            : double.parse((total / 1.18).toStringAsFixed(2));

    final igv =
        tax > 0 ? tax : double.parse((total - gravada).toStringAsFixed(2));

    return ReceiptTaxHelper._(
      opGravada: gravada,
      igvAmount: igv,
      totalAmount: total,
      discountAmount: order.discountAmount,
      pointsUsed: order.pointsUsed,
    );
  }

  static String formatCurrency(double amount, {String symbol = 'S/'}) {
    return '$symbol ${amount.toStringAsFixed(2)}';
  }
}
