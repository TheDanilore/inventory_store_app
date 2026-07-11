import 'package:inventory_store_app/features/inventory/domain/entities/inventory_exit_entity.dart';
class InventoryExitModel {
  final String id;
  final String warehouseId;
  final String? reason;
  final String? notes;
  final String? createdBy;
  final DateTime? createdAt;

  // Campos adicionales útiles al hacer JOIN con otras tablas
  final String? warehouseName;
  final double totalCost;
  final int itemCount;

  InventoryExitModel({
    required this.id,
    required this.warehouseId,
    this.reason,
    this.notes,
    this.createdBy,
    this.createdAt,
    this.warehouseName,
    this.totalCost = 0.0,
    this.itemCount = 0,
  });

  /// Factory para mapear los datos JSON de la Base de Datos a la clase de Flutter
  factory InventoryExitModel.fromJson(Map<String, dynamic> json) {
    return InventoryExitModel(
      id: json['id'] as String,
      warehouseId: json['warehouse_id'] as String? ?? '',
      reason: json['reason'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : null,
      warehouseName: json['warehouses']?['name'] as String?,
      totalCost:
          json['total_cost'] != null
              ? (json['total_cost'] as num).toDouble()
              : (() {
                double t = 0;
                final items = json['inventory_exit_items'] as List?;
                if (items != null) {
                  for (var item in items) {
                    t +=
                        ((item['quantity'] as num?)?.toDouble() ?? 0) *
                        ((item['unit_cost'] as num?)?.toDouble() ?? 0);
                  }
                }
                return t;
              })(),
      itemCount:
          (json['inventory_exit_items'] as List?)?.length ??
          (json['item_count'] as int? ?? 0),
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
    String? warehouseName,
    double? totalCost,
    int? itemCount,
  }) {
    return InventoryExitModel(
      id: id ?? this.id,
      warehouseId: warehouseId ?? this.warehouseId,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      warehouseName: warehouseName ?? this.warehouseName,
      totalCost: totalCost ?? this.totalCost,
      itemCount: itemCount ?? this.itemCount,
    );
  }

  InventoryExitEntity toEntity() {
    return InventoryExitEntity(
      id: id,
      warehouseId: warehouseId,
      reason: reason,
      notes: notes,
      createdBy: createdBy,
      createdAt: createdAt,
      warehouseName: warehouseName,
      totalCost: totalCost,
      itemCount: itemCount,
    );
  }
}
