class InventoryEntryModel {
  final String id;
  final String warehouseId;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;

  InventoryEntryModel({
    required this.id,
    required this.warehouseId,
    this.notes,
    this.createdBy,
    this.createdAt,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory InventoryEntryModel.fromJson(Map<String, dynamic> json) {
    return InventoryEntryModel(
      id: json['id'] as String,
      warehouseId: json['warehouse_id'] as String,
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
      'notes': notes,
      'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Método copyWith ideal para el manejo de estados (Bloc, Riverpod, etc.)
  InventoryEntryModel copyWith({
    String? id,
    String? warehouseId,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
  }) {
    return InventoryEntryModel(
      id: id ?? this.id,
      warehouseId: warehouseId ?? this.warehouseId,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
