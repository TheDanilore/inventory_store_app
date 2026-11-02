import 'package:inventory_store_app/features/customers/domain/entities/credit_movement_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_movement_entity.dart';

/// Modelo transversal para representar un movimiento en el estado de cuenta
class StatementItem {
  final DateTime? date;
  final bool isCharge;
  final double amount;
  final String? method;
  final String? notes;
  final String? user;

  const StatementItem({
    required this.date,
    required this.isCharge,
    required this.amount,
    this.method,
    this.notes,
    this.user,
  });

  factory StatementItem.fromCustomer(CreditMovementEntity m) {
    return StatementItem(
      date: m.createdAt,
      isCharge: m.movementType == 'CHARGE',
      amount: m.amount,
      method: m.paymentMethod,
      notes: m.notes,
      user: m.createdByName,
    );
  }

  factory StatementItem.fromSupplier(SupplierCreditMovementEntity m) {
    return StatementItem(
      date: m.createdAt,
      isCharge: m.isCharge,
      amount: m.amount,
      method: m.paymentMethod,
      notes: m.notes,
      user: m.createdByName,
    );
  }
}
