import 'package:equatable/equatable.dart';

class InventoryEntryEntity extends Equatable {
  final String id;
  final String warehouseId;
  final String? supplierId;
  final String? purchaseOrderId;
  final String? notes;
  final double totalAmount;
  final String documentType;
  final String? documentNumber;
  final DateTime? documentDate;
  final String? createdBy;
  final DateTime? createdAt;
  final String? warehouseName;
  final String? supplierName;
  final int itemCount;

  const InventoryEntryEntity({
    required this.id,
    required this.warehouseId,
    this.supplierId,
    this.purchaseOrderId,
    this.notes,
    required this.totalAmount,
    required this.documentType,
    this.documentNumber,
    this.documentDate,
    this.createdBy,
    this.createdAt,
    this.warehouseName,
    this.supplierName,
    required this.itemCount,
  });

  @override
  List<Object?> get props => [
    id,
    warehouseId,
    supplierId,
    purchaseOrderId,
    notes,
    totalAmount,
    documentType,
    documentNumber,
    documentDate,
    createdBy,
    createdAt,
    warehouseName,
    supplierName,
    itemCount,
  ];
}
