class SupplierCreditMovementModel {
  final String id;
  final String creditId;
  final String? purchaseOrderId;
  final String movementType;
  final double amount;
  final String? paymentMethod;
  final String? notes;
  final DateTime? createdAt;
  final String? createdByName;
  final double? orderTotalAmount;

  bool get isCharge => movementType == 'CHARGE';

  const SupplierCreditMovementModel({
    required this.id,
    required this.creditId,
    this.purchaseOrderId,
    required this.movementType,
    required this.amount,
    this.paymentMethod,
    this.notes,
    this.createdAt,
    this.createdByName,
    this.orderTotalAmount,
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
