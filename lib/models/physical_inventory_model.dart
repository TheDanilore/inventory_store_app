class PhysicalInventoryModel {
  final String id;
  final String warehouseId;
  final String status; // 'PENDING', 'COMPLETED', 'CANCELLED'
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PhysicalInventoryModel({
    required this.id,
    required this.warehouseId,
    this.status = 'PENDING',
    this.notes,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory PhysicalInventoryModel.fromJson(Map<String, dynamic> json) {
    return PhysicalInventoryModel(
      id: json['id'] as String,
      warehouseId: json['warehouse_id'] as String,
      status: json['status'] as String? ?? 'PENDING',
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null,
      updatedAt:
          json['updated_at'] != null
              ? DateTime.parse(json['updated_at'] as String)
              : null,
    );
  }

  /// Método para convertir el modelo de Dart a un mapa estructurado para insertar/actualizar en SQL
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'warehouse_id': warehouseId,
      'status': status,
      'notes': notes,
      'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  /// Método copyWith ideal para el manejo de estados (Bloc, Riverpod, etc.)
  PhysicalInventoryModel copyWith({
    String? id,
    String? warehouseId,
    String? status,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PhysicalInventoryModel(
      id: id ?? this.id,
      warehouseId: warehouseId ?? this.warehouseId,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
