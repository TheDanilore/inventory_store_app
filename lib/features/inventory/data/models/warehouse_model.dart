import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_layout_config.dart';

class WarehouseModel {
  final String? id;
  final String name;
  final String? address;
  final bool isActive;
  final DateTime? createdAt;
  final String? createdBy;
  final String? updatedBy;
  final String type;
  final String? code;
  final WarehouseLayoutConfig layoutConfig;

  static var warehouseNames = <String, String>{};

  const WarehouseModel({
    this.id,
    required this.name,
    this.address,
    this.isActive = true,
    this.createdAt,
    this.createdBy,
    this.updatedBy,
    this.type = 'warehouse',
    this.code,
    this.layoutConfig = const WarehouseLayoutConfig(),
  });

  factory WarehouseModel.fromJson(Map<String, dynamic> json) {
    return WarehouseModel(
      id: json['id'] as String?,
      name: json['name'] as String? ?? 'Sin nombre',
      address: json['address'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : null,
      createdBy: json['created_by'] as String?,
      updatedBy: json['updated_by'] as String?,
      type: json['type'] as String? ?? 'warehouse',
      code: json['code'] as String?,
      layoutConfig:
          json['layout_config'] is Map
              ? WarehouseLayoutConfig.fromJson(
                Map<String, dynamic>.from(json['layout_config'] as Map),
              )
              : const WarehouseLayoutConfig(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      if (address != null) 'address': address,
      'is_active': isActive,
      if (createdBy != null) 'created_by': createdBy,
      if (updatedBy != null) 'updated_by': updatedBy,
      'type': type,
      if (code != null) 'code': code,
      'layout_config': layoutConfig.toJson(),
    };
  }

  WarehouseEntity toEntity() {
    return WarehouseEntity(
      id: id ?? '',
      name: name,
      address: address,
      isActive: isActive,
      createdAt: createdAt,
      createdBy: createdBy,
      updatedBy: updatedBy,
      type: type,
      code: code,
      layoutConfig: layoutConfig,
    );
  }
}
