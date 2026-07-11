import 'package:equatable/equatable.dart';

class KardexMovementEntity extends Equatable {
  final String id;
  final DateTime date;
  final String type;
  final String reference;
  final String description;
  final double quantity;
  final double balance;
  final double unitCost;
  final double totalCost;
  final String variantId;
  final String warehouseId;

  const KardexMovementEntity({
    required this.id,
    required this.date,
    required this.type,
    required this.reference,
    required this.description,
    required this.quantity,
    required this.balance,
    required this.unitCost,
    required this.totalCost,
    required this.variantId,
    required this.warehouseId,
  });

  @override
  List<Object?> get props => [
        id, date, type, reference, description, quantity,
        balance, unitCost, totalCost, variantId, warehouseId,
      ];
}
