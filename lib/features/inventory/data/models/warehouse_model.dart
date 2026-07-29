import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';

class WarehouseModel {
  final String? id;
  final String name;
  final String? address;
  final bool isActive;
  final DateTime? createdAt;
  final String? createdBy;
  final String? updatedBy;

  static var warehouseNames = <String, String>{};

  const WarehouseModel({
    this.id,
    required this.name,
    this.address,
    this.isActive = true,
    this.createdAt,
    this.createdBy,
    this.updatedBy,
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
    );
  }
}
