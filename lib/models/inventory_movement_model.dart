class InventoryMovementModel {
  final String id;
  final String variantId;
  final String warehouseId;
  final String? stockBatchId;
  final String? orderId;
  final String? inventoryEntryId;
  final String? inventoryExitId;
  final String? physicalInventoryId;
  final double quantity;
  final double previousStock;
  final double newStock;
  final double? unitCost;
  final double? totalCost;
  final String reason;
  final String? notes;
  final String createdBy;
  final DateTime? createdAt;

  InventoryMovementModel({
    required this.id,
    required this.variantId,
    required this.warehouseId,
    this.stockBatchId,
    this.orderId,
    this.inventoryEntryId,
    this.inventoryExitId,
    this.physicalInventoryId,
    required this.quantity,
    required this.previousStock,
    required this.newStock,
    this.unitCost,
    this.totalCost,
    required this.reason,
    this.notes,
    required this.createdBy,
    this.createdAt,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory InventoryMovementModel.fromJson(Map<String, dynamic> json) {
    return InventoryMovementModel(
      id: json['id'] as String,
      variantId: json['variant_id'] as String,
      warehouseId: json['warehouse_id'] as String,
      stockBatchId: json['stock_batch_id'] as String?,
      orderId: json['order_id'] as String?,
      inventoryEntryId: json['inventory_entry_id'] as String?,
      inventoryExitId: json['inventory_exit_id'] as String?,
      physicalInventoryId: json['physical_inventory_id'] as String?,
      // Conversión segura de campos numéricos (numeric de SQL a double de Dart)
      quantity: (json['quantity'] as num).toDouble(),
      previousStock: (json['previous_stock'] as num).toDouble(),
      newStock: (json['new_stock'] as num).toDouble(),
      unitCost:
          json['unit_cost'] != null
              ? (json['unit_cost'] as num).toDouble()
              : null,
      totalCost:
          json['total_cost'] != null
              ? (json['total_cost'] as num).toDouble()
              : null,
      reason: json['reason'] as String,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null,
    );
  }

  /// Método para convertir el modelo de Dart a un mapa estructurado para insertar/actualizar en SQL
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'variant_id': variantId,
      'warehouse_id': warehouseId,
      'stock_batch_id': stockBatchId,
      'order_id': orderId,
      'inventory_entry_id': inventoryEntryId,
      'inventory_exit_id': inventoryExitId,
      'physical_inventory_id': physicalInventoryId,
      'quantity': quantity,
      'previous_stock': previousStock,
      'new_stock': newStock,
      'unit_cost': unitCost,
      'total_cost': totalCost,
      'reason': reason,
      'notes': notes,
      'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Método copyWith ideal para el manejo de estados (Bloc, Riverpod, etc.)
  InventoryMovementModel copyWith({
    String? id,
    String? variantId,
    String? warehouseId,
    String? stockBatchId,
    String? orderId,
    String? inventoryEntryId,
    String? inventoryExitId,
    String? physicalInventoryId,
    double? quantity,
    double? previousStock,
    double? newStock,
    double? unitCost,
    double? totalCost,
    String? reason,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return InventoryMovementModel(
      id: id ?? this.id,
      variantId: variantId ?? this.variantId,
      warehouseId: warehouseId ?? this.warehouseId,
      stockBatchId: stockBatchId ?? this.stockBatchId,
      orderId: orderId ?? this.orderId,
      inventoryEntryId: inventoryEntryId ?? this.inventoryEntryId,
      inventoryExitId: inventoryExitId ?? this.inventoryExitId,
      physicalInventoryId: physicalInventoryId ?? this.physicalInventoryId,
      quantity: quantity ?? this.quantity,
      previousStock: previousStock ?? this.previousStock,
      newStock: newStock ?? this.newStock,
      unitCost: unitCost ?? this.unitCost,
      totalCost: totalCost ?? this.totalCost,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
