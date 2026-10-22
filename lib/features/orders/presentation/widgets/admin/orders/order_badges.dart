import 'package:flutter/material.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';

/// Fuente única de verdad para los badges de estado / pago de un pedido.
///
/// La usan: AdminOrderCard, OrdersTableView y PosSalesView. Antes cada una
/// tenía su propio mapeo y se contradecían (p. ej. la tabla mostraba
/// "PENDING" crudo, el POS "Pendiente" y las cards "Borrador").
///
/// Ubicación sugerida:
/// lib/features/orders/presentation/widgets/admin/orders/order_badges.dart

// ─── Tonos ──────────────────────────────────────────────────────────────────

enum OrderTone { success, warning, danger, info, violet, neutral }

class OrderToneColors {
  final Color background;
  final Color border;
  final Color foreground;
  const OrderToneColors(this.background, this.border, this.foreground);
}

extension OrderToneX on OrderTone {
  OrderToneColors get colors => switch (this) {
    OrderTone.success => const OrderToneColors(
      Color(0xFFECFDF5),
      Color(0xFFA7F3D0),
      Color(0xFF047857),
    ),
    OrderTone.warning => const OrderToneColors(
      Color(0xFFFFFBEB),
      Color(0xFFFDE68A),
      Color(0xFFB45309),
    ),
    OrderTone.danger => const OrderToneColors(
      Color(0xFFFFF1F2),
      Color(0xFFFECDD3),
      Color(0xFFBE123C),
    ),
    OrderTone.info => const OrderToneColors(
      Color(0xFFEFF6FF),
      Color(0xFFBFDBFE),
      Color(0xFF1D4ED8),
    ),
    OrderTone.violet => const OrderToneColors(
      Color(0xFFF5F3FF),
      Color(0xFFDDD6FE),
      Color(0xFF6D28D9),
    ),
    OrderTone.neutral => const OrderToneColors(
      Color(0xFFF1F5F9),
      Color(0xFFCBD5E1),
      Color(0xFF475569),
    ),
  };
}

// ─── Helpers de dominio ─────────────────────────────────────────────────────

bool isCreditPayment(String method) {
  final m = method.trim().toUpperCase();
  return m == 'CRÉDITO' || m == 'CREDITO';
}

String orderShortId(String id) {
  final short = id.length >= 8 ? id.substring(0, 8) : id;
  return short.toUpperCase();
}

bool isDraftStatus(String status) {
  final s = status.toUpperCase();
  return s == 'PENDING' || s == 'DRAFT';
}

// ─── Estado del pedido ──────────────────────────────────────────────────────

class OrderStatusInfo {
  final String label;
  final IconData icon;
  final OrderTone tone;
  const OrderStatusInfo(this.label, this.icon, this.tone);

  factory OrderStatusInfo.from(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'DELIVERED':
        return const OrderStatusInfo(
          'Completado',
          Icons.check_circle_rounded,
          OrderTone.success,
        );
      case 'PENDING':
      case 'DRAFT':
        return const OrderStatusInfo(
          'Borrador',
          Icons.edit_note_rounded,
          OrderTone.warning,
        );
      case 'CANCELLED':
        return const OrderStatusInfo(
          'Cancelado',
          Icons.cancel_rounded,
          OrderTone.danger,
        );
      case 'RETURNED':
      case 'REFUNDED':
        return const OrderStatusInfo(
          'Devuelto',
          Icons.assignment_return_rounded,
          OrderTone.violet,
        );
      default:
        return OrderStatusInfo(
          status,
          Icons.info_outline_rounded,
          OrderTone.neutral,
        );
    }
  }
}

// ─── Estado de cobro ────────────────────────────────────────────────────────

class OrderPaymentInfo {
  final String label;
  final IconData icon;
  final OrderTone tone;
  final bool isCredit;
  final double paid;
  final double remaining;

  const OrderPaymentInfo({
    required this.label,
    required this.icon,
    required this.tone,
    required this.isCredit,
    required this.paid,
    required this.remaining,
  });

  /// Devuelve `null` cuando el cobro no aplica (pedido cancelado / devuelto):
  /// el badge de estado ya lo dice, repetirlo ("CANCELADO" + "ANULADO") es ruido.
  static OrderPaymentInfo? from(OrderEntity order) {
    final status = order.status.toUpperCase();
    if (status == 'CANCELLED' || status == 'RETURNED' || status == 'REFUNDED') {
      return null;
    }

    final credit = isCreditPayment(order.paymentMethod);
    final total = order.totalAmount;

    // Un borrador nunca se cobró: no puede decir "Pagado".
    if (isDraftStatus(status)) {
      return OrderPaymentInfo(
        label: 'Sin cobrar',
        icon: Icons.hourglass_empty_rounded,
        tone: OrderTone.warning,
        isCredit: credit,
        paid: 0,
        remaining: total,
      );
    }

    var paid = order.amountPaid;
    var paymentStatus = order.paymentStatus.toUpperCase();
    if (!credit && (status == 'COMPLETED' || status == 'DELIVERED')) {
      paymentStatus = 'PAID';
      paid = total;
    }

    final remaining = total - paid > 0 ? total - paid : 0.0;

    if (paymentStatus == 'PAID' || remaining <= 0) {
      return OrderPaymentInfo(
        label: 'Pagado',
        icon: Icons.done_all_rounded,
        tone: OrderTone.success,
        isCredit: credit,
        paid: paid,
        remaining: 0,
      );
    }
    if (paymentStatus == 'PARTIAL' || paid > 0) {
      return OrderPaymentInfo(
        label: 'Parcial',
        icon: Icons.donut_large_rounded,
        tone: OrderTone.info,
        isCredit: credit,
        paid: paid,
        remaining: remaining,
      );
    }
    return OrderPaymentInfo(
      label: 'Por cobrar',
      icon: Icons.schedule_rounded,
      tone: OrderTone.warning,
      isCredit: credit,
      paid: paid,
      remaining: remaining,
    );
  }
}

// ─── Widgets ────────────────────────────────────────────────────────────────

class OrderChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final OrderTone tone;
  final bool dense;

  const OrderChip({
    super.key,
    required this.label,
    required this.tone,
    this.icon,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = tone.colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2.5 : 3.5,
      ),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11.5 : 12.5, color: c.foreground),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: dense ? 10.5 : 11,
                fontWeight: FontWeight.w800,
                color: c.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OrderStatusBadge extends StatelessWidget {
  final String status;
  final bool dense;
  const OrderStatusBadge({super.key, required this.status, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final info = OrderStatusInfo.from(status);
    return OrderChip(
      label: info.label,
      icon: info.icon,
      tone: info.tone,
      dense: dense,
    );
  }
}

class OrderPaymentBadge extends StatelessWidget {
  final OrderPaymentInfo info;
  final bool dense;
  const OrderPaymentBadge({super.key, required this.info, this.dense = false});

  @override
  Widget build(BuildContext context) {
    return OrderChip(
      label: info.label,
      icon: info.icon,
      tone: info.tone,
      dense: dense,
    );
  }
}
