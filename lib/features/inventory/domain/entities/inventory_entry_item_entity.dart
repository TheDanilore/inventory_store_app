import 'package:equatable/equatable.dart';

class InventoryEntryItemEntity extends Equatable {
  final String productId;
  final String productName;
  final String variantId;
  final String variantLabel;
  final String? imageUrl;
  final bool usesBatches;
  final double quantity;
  final double unitCost;
  final String batchNumber;
  final DateTime? expiryDate;

  const InventoryEntryItemEntity({
    required this.productId,
    required this.productName,
    required this.variantId,
    required this.variantLabel,
    this.imageUrl,
    required this.usesBatches,
    required this.quantity,
    required this.unitCost,
    required this.batchNumber,
    this.expiryDate,
  });

  double get subtotal => quantity * unitCost;

  InventoryEntryItemEntity copyWith({
    String? productId,
    String? productName,
    String? variantId,
    String? variantLabel,
    String? imageUrl,
    bool? usesBatches,
    double? quantity,
    double? unitCost,
    String? batchNumber,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
  }) {
    return InventoryEntryItemEntity(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      variantId: variantId ?? this.variantId,
      variantLabel: variantLabel ?? this.variantLabel,
      imageUrl: imageUrl ?? this.imageUrl,
      usesBatches: usesBatches ?? this.usesBatches,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
    );
  }

  @override
  List<Object?> get props => [
        productId,
        productName,
        variantId,
        variantLabel,
        imageUrl,
        usesBatches,
        quantity,
        unitCost,
        batchNumber,
        expiryDate,
      ];
}