class InventoryExitModel {
  final String id;
  final String warehouseId;
  final String? reason;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;

  InventoryExitModel({
    required this.id,
    required this.warehouseId,
    this.reason,
    this.notes,
    this.createdBy,
    this.createdAt,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory InventoryExitModel.fromJson(Map<String, dynamic> json) {
    return InventoryExitModel(
      id: json['id'] as String,
      warehouseId: json['warehouse_id'] as String,
      reason: json['reason'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
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
      'warehouse_id': warehouseId,
      'reason': reason,
      'notes': notes,
      'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Método copyWith ideal para el manejo de estados (Bloc, Riverpod, etc.)
  InventoryExitModel copyWith({
    String? id,
    String? warehouseId,
    String? reason,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return InventoryExitModel(
      id: id ?? this.id,
      warehouseId: warehouseId ?? this.warehouseId,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
