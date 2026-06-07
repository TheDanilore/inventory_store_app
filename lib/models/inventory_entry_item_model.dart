class InventoryEntryItemModel {
  final String id;
  final String entryId;
  final String productId;
  final String variantId;
  final double quantity;
  final double unitCost;
  final String batchNumber; // 'DEFAULT' por defecto
  final DateTime? expiryDate;
  final DateTime? createdAt;

  InventoryEntryItemModel({
    required this.id,
    required this.entryId,
    required this.productId,
    required this.variantId,
    required this.quantity,
    required this.unitCost,
    this.batchNumber = 'DEFAULT',
    this.expiryDate,
    this.createdAt,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory InventoryEntryItemModel.fromJson(Map<String, dynamic> json) {
    return InventoryEntryItemModel(
      id: json['id'] as String,
      entryId: json['entry_id'] as String,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String,
      // Conversión segura de campos numéricos (numeric de SQL a double de Dart)
      quantity: (json['quantity'] as num).toDouble(),
      unitCost: (json['unit_cost'] as num).toDouble(),
      batchNumber: json['batch_number'] as String? ?? 'DEFAULT',
      expiryDate:
          json['expiry_date'] != null
              ? DateTime.parse(json['expiry_date'] as String)
              : null,
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
      'entry_id': entryId,
      'product_id': productId,
      'variant_id': variantId,
      'quantity': quantity,
      'unit_cost': unitCost,
      'batch_number': batchNumber,
      // Formato YYYY-MM-DD para la columna DATE de PostgreSQL
      'expiry_date': expiryDate?.toIso8601String().split('T').first,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Método copyWith ideal para el manejo de estados (Bloc, Riverpod, etc.)
  InventoryEntryItemModel copyWith({
    String? id,
    String? entryId,
    String? productId,
    String? variantId,
    double? quantity,
    double? unitCost,
    String? batchNumber,
    DateTime? expiryDate,
    DateTime? createdAt,
  }) {
    return InventoryEntryItemModel(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
