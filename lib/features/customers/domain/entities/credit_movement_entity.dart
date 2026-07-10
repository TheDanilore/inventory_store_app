import 'package:equatable/equatable.dart';

class CreditMovementEntity extends Equatable {
  final String id;
  final String customerCreditId;
  final String? orderId;
  final String movementType; // 'CHARGE' o 'PAYMENT'
  final double amount;
  final String? paymentMethod;
  final String? notes;
  final DateTime? createdAt;
  final String? createdBy;

  final String? createdByName;
  final String? customerName;
  final String? orderPaymentMethod;
  final double? orderTotalAmount;
  final String? orderNumber;

  const CreditMovementEntity({
    required this.id,
    required this.customerCreditId,
    this.orderId,
    required this.movementType,
    required this.amount,
    this.paymentMethod,
    this.notes,
    this.createdAt,
    this.createdBy,
    this.createdByName,
    this.customerName,
    this.orderPaymentMethod,
    this.orderTotalAmount,
    this.orderNumber,
  });

  @override
  List<Object?> get props => [
        id,
        customerCreditId,
        orderId,
        movementType,
        amount,
        paymentMethod,
        notes,
        createdAt,
        createdBy,
        createdByName,
        customerName,
        orderPaymentMethod,
        orderTotalAmount,
        orderNumber,
      ];
}
