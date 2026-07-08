class PhysicalInventoryItemModel {
  final String id;
  final String physicalInventoryId;
  final String variantId;
  final String? batchNumber;
  final DateTime? expiryDate;
  final double systemQuantity;
  final double? countedQuantity;
  final double? difference;
  final double? unitCost;
  final double? totalDifferenceCost;
  final String? notes;
  final String? countedBy;
  final DateTime? countedAt;

  PhysicalInventoryItemModel({
    required this.id,
    required this.physicalInventoryId,
    required this.variantId,
    this.batchNumber,
    this.expiryDate,
    required this.systemQuantity,
    this.countedQuantity,
    this.difference,
    this.unitCost,
    this.totalDifferenceCost,
    this.notes,
    this.countedBy,
    this.countedAt,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory PhysicalInventoryItemModel.fromJson(Map<String, dynamic> json) {
    return PhysicalInventoryItemModel(
      id: json['id'] as String,
      physicalInventoryId: json['physical_inventory_id'] as String,
      variantId: json['variant_id'] as String,
      batchNumber: json['batch_number'] as String?,
      expiryDate:
          json['expiry_date'] != null
              ? DateTime.parse(json['expiry_date'] as String)
              : null,
      systemQuantity: (json['system_quantity'] as num).toDouble(),
      countedQuantity:
          json['counted_quantity'] != null
              ? (json['counted_quantity'] as num).toDouble()
              : null,
      difference:
          json['difference'] != null
              ? (json['difference'] as num).toDouble()
              : null,
      unitCost:
          json['unit_cost'] != null
              ? (json['unit_cost'] as num).toDouble()
              : null,
      totalDifferenceCost:
          json['total_difference_cost'] != null
              ? (json['total_difference_cost'] as num).toDouble()
              : null,
      notes: json['notes'] as String?,
      countedBy: json['counted_by'] as String?,
      countedAt:
          json['counted_at'] != null
              ? DateTime.parse(json['counted_at'] as String)
              : null,
    );
  }

  /// Método para convertir el modelo de Dart a un mapa estructurado para insertar/actualizar en SQL
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'physical_inventory_id': physicalInventoryId,
      'variant_id': variantId,
      'batch_number': batchNumber,
      // Se formatea YYYY-MM-DD para columnas de tipo DATE en SQL
      'expiry_date': expiryDate?.toIso8601String().split('T').first,
      'system_quantity': systemQuantity,
      'counted_quantity': countedQuantity,
      'difference': difference,
      'unit_cost': unitCost,
      'total_difference_cost': totalDifferenceCost,
      'notes': notes,
      'counted_by': countedBy,
      if (countedAt != null) 'counted_at': countedAt!.toIso8601String(),
    };
  }

  /// Método copyWith ideal para el manejo de estados (Bloc, Riverpod, etc.)
  PhysicalInventoryItemModel copyWith({
    String? id,
    String? physicalInventoryId,
    String? variantId,
    String? batchNumber,
    DateTime? expiryDate,
    double? systemQuantity,
    double? countedQuantity,
    double? difference,
    double? unitCost,
    double? totalDifferenceCost,
    String? notes,
    String? countedBy,
    DateTime? createdAt,
    DateTime? countedAt,
  }) {
    return PhysicalInventoryItemModel(
      id: id ?? this.id,
      physicalInventoryId: physicalInventoryId ?? this.physicalInventoryId,
      variantId: variantId ?? this.variantId,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      systemQuantity: systemQuantity ?? this.systemQuantity,
      countedQuantity: countedQuantity ?? this.countedQuantity,
      difference: difference ?? this.difference,
      unitCost: unitCost ?? this.unitCost,
      totalDifferenceCost: totalDifferenceCost ?? this.totalDifferenceCost,
      notes: notes ?? this.notes,
      countedBy: countedBy ?? this.countedBy,
      countedAt: countedAt ?? this.countedAt,
    );
  }
}
