class InventoryExitItemModel {
  final String id;
  final String exitId;
  final String productId;
  final String variantId;
  final double quantity;
  final String batchNumber; // 'DEFAULT' por defecto según tu SQL
  final DateTime? createdAt;

  InventoryExitItemModel({
    required this.id,
    required this.exitId,
    required this.productId,
    required this.variantId,
    required this.quantity,
    this.batchNumber = 'DEFAULT',
    this.createdAt,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory InventoryExitItemModel.fromJson(Map<String, dynamic> json) {
    return InventoryExitItemModel(
      id: json['id'] as String,
      exitId: json['exit_id'] as String,
      productId: json['product_id'] as String,
      variantId: json['variant_id'] as String,
      // Conversión segura de campos numéricos (numeric de SQL a double de Dart)
      quantity: (json['quantity'] as num).toDouble(),
      batchNumber: json['batch_number'] as String? ?? 'DEFAULT',
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
      'exit_id': exitId,
      'product_id': productId,
      'variant_id': variantId,
      'quantity': quantity,
      'batch_number': batchNumber,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Método copyWith ideal para el manejo de estados (Bloc, Riverpod, etc.)
  InventoryExitItemModel copyWith({
    String? id,
    String? exitId,
    String? productId,
    String? variantId,
    double? quantity,
    String? batchNumber,
    DateTime? createdAt,
  }) {
    return InventoryExitItemModel(
      id: id ?? this.id,
      exitId: exitId ?? this.exitId,
      productId: productId ?? this.productId,
      variantId: variantId ?? this.variantId,
      quantity: quantity ?? this.quantity,
      batchNumber: batchNumber ?? this.batchNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
