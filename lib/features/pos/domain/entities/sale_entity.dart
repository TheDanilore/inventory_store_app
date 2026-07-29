import 'package:inventory_store_app/features/inventory/data/models/batch_assignment_model.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cash_shift_entity.dart';

/// Entidad de una venta completada en el POS.
///
/// Agrupa todos los datos necesarios para procesar y registrar
/// una venta, incluyendo sus ítems, método de pago y cliente.
class SaleEntity {
  final List<SaleItemEntity> items;
  final String? customerId;
  final String? customerName;
  final String warehouseId;
  final String? accountId;
  final String paymentMethod;
  final SalePaymentStatus paymentStatus;
  final double totalAmount;
  final double totalProfit;
  final double discountAmount;
  final double amountPaid;
  final int pointsUsed;
  final int pointsEarned;
  final bool isDraft;
  final bool isCredit;
  final CashShiftEntity? activeShift;

  const SaleEntity({
    required this.items,
    required this.warehouseId,
    required this.paymentMethod,
    required this.totalAmount,
    required this.totalProfit,
    this.customerId,
    this.customerName,
    this.accountId,
    this.paymentStatus = SalePaymentStatus.paid,
    this.discountAmount = 0,
    this.amountPaid = 0,
    this.pointsUsed = 0,
    this.pointsEarned = 0,
    this.isDraft = false,
    this.isCredit = false,
    this.activeShift,
  });

  // ── Lógica de negocio ─────────────────────────────────────────────────────

  bool get hasCustomer => customerId != null;
  bool get hasDiscount => discountAmount > 0;
  bool get usesPoints => pointsUsed > 0;
  bool get earnsPoints => pointsEarned > 0;
  int get totalItems => items.fold(0, (sum, i) => sum + i.quantity);

  double get netTotal => totalAmount - discountAmount;

  @override
  String toString() =>
      'SaleEntity(total: $totalAmount, items: ${items.length}, draft: $isDraft)';
}

/// Un ítem dentro de la venta.
class SaleItemEntity {
  final String productId;
  final String? variantId;
  final int quantity;
  final double unitCost;
  final double appliedPrice;
  final List<BatchAssignmentModel>? batchAssignments;

  const SaleItemEntity({
    required this.productId,
    required this.quantity,
    required this.unitCost,
    required this.appliedPrice,
    this.variantId,
    this.batchAssignments,
  });

  double get netProfit => (appliedPrice - unitCost) * quantity;
  double get subtotal => appliedPrice * quantity;
}

enum SalePaymentStatus {
  paid,
  pending,
  credit;

  static SalePaymentStatus fromString(String value) {
    return switch (value.toUpperCase()) {
      'PAID' => SalePaymentStatus.paid,
      'PENDING' => SalePaymentStatus.pending,
      'CREDIT' => SalePaymentStatus.credit,
      _ => SalePaymentStatus.pending,
    };
  }

  String toSupabaseString() {
    return switch (this) {
      SalePaymentStatus.paid => 'PAID',
      SalePaymentStatus.pending => 'PENDING',
      SalePaymentStatus.credit => 'CREDIT',
    };
  }
}
