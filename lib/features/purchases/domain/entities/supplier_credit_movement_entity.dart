import 'package:equatable/equatable.dart';

class SupplierCreditMovementEntity extends Equatable {
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

  const SupplierCreditMovementEntity({
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

  @override
  List<Object?> get props => [
    id,
    creditId,
    purchaseOrderId,
    movementType,
    amount,
    paymentMethod,
    notes,
    createdAt,
    createdByName,
    orderTotalAmount,
  ];
}
