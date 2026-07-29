import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_movement_entity.dart';

class SupplierCreditMovementModel extends SupplierCreditMovementEntity {
  const SupplierCreditMovementModel({
    required super.id,
    required super.creditId,
    super.purchaseOrderId,
    required super.movementType,
    required super.amount,
    super.paymentMethod,
    super.notes,
    super.createdAt,
    super.createdByName,
    super.orderTotalAmount,
  });

  factory SupplierCreditMovementModel.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    final po = json['purchase_orders'] as Map<String, dynamic>?;

    return SupplierCreditMovementModel(
      id: json['id'] as String,
      creditId: json['supplier_credit_id'] as String,
      purchaseOrderId: json['purchase_order_id'] as String?,
      movementType: json['movement_type'] as String,
      amount: (json['amount'] as num).toDouble(),
      paymentMethod: json['payment_method'] as String?,
      notes: json['notes'] as String?,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'])
              : null,
      createdByName: profile?['full_name'] as String?,
      orderTotalAmount:
          po?['total_amount'] != null
              ? (po!['total_amount'] as num).toDouble()
              : null,
    );
  }
}
