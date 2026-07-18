import 'package:equatable/equatable.dart';

class InventoryExitEntity extends Equatable {
  final String id;
  final String warehouseId;
  final String? reason;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;
  final String? warehouseName;
  final double totalCost;
  final int itemCount;

  const InventoryExitEntity({
    required this.id,
    required this.warehouseId,
    this.reason,
    this.notes,
    this.createdBy,
    this.createdAt,
    this.warehouseName,
    required this.totalCost,
    required this.itemCount,
  });

  @override
  List<Object?> get props => [
    id,
    warehouseId,
    reason,
    notes,
    createdBy,
    createdAt,
    warehouseName,
    totalCost,
    itemCount,
  ];
}
