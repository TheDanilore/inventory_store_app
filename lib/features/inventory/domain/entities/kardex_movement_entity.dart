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
  final String? productName;
  final String? attrsText;
  final String? sku;
  final String? imageUrl;
  final String? warehouseName;
  final String? batchNumber;

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
    this.productName,
    this.attrsText,
    this.sku,
    this.imageUrl,
    this.warehouseName,
    this.batchNumber,
  });

  @override
  List<Object?> get props => [
    id,
    date,
    type,
    reference,
    description,
    quantity,
    balance,
    unitCost,
    totalCost,
    variantId,
    warehouseId,
    productName,
    attrsText,
    sku,
    imageUrl,
    warehouseName,
    batchNumber,
  ];
}
