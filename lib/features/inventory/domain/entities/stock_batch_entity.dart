import 'package:equatable/equatable.dart';

class StockBatchEntity extends Equatable {
  final String id;
  final String variantId;
  final String warehouseId;
  final String batchNumber;
  final DateTime? expiryDate;
  final double availableQuantity;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdBy;
  final String? updatedBy;
  final String productId;

  const StockBatchEntity({
    required this.id,
    required this.variantId,
    required this.warehouseId,
    required this.batchNumber,
    this.expiryDate,
    required this.availableQuantity,
    this.createdAt,
    this.updatedAt,
    this.createdBy,
    this.updatedBy,
    required this.productId,
  });

  bool get isOutOfStock => availableQuantity <= 0;

  @override
  List<Object?> get props => [
        id, variantId, warehouseId, batchNumber, expiryDate,
        availableQuantity, createdAt, updatedAt, createdBy, updatedBy, productId,
      ];
}
