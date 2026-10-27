import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_layout_config.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_type.dart';

class WarehouseEntity extends Equatable {
  final String id;
  final String name;
  final String? address;
  final bool isActive;
  final DateTime? createdAt;
  final String? createdBy;
  final String? updatedBy;
  final String type;
  final String? code;
  final WarehouseLayoutConfig layoutConfig;

  const WarehouseEntity({
    required this.id,
    required this.name,
    this.address,
    required this.isActive,
    this.createdAt,
    this.createdBy,
    this.updatedBy,
    this.type = 'warehouse',
    this.code,
    this.layoutConfig = const WarehouseLayoutConfig(),
  });

  WarehouseType get warehouseType => WarehouseType.fromString(type);
  bool get isStore => warehouseType == WarehouseType.store;
  bool get isCentral => warehouseType == WarehouseType.central;
  bool get isDarkStore => warehouseType == WarehouseType.darkStore;
  bool get isTransit => warehouseType == WarehouseType.transit;

  WarehouseEntity copyWith({
    String? id,
    String? name,
    String? address,
    bool? isActive,
    DateTime? createdAt,
    String? createdBy,
    String? updatedBy,
    String? type,
    String? code,
    WarehouseLayoutConfig? layoutConfig,
  }) {
    return WarehouseEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
      type: type ?? this.type,
      code: code ?? this.code,
      layoutConfig: layoutConfig ?? this.layoutConfig,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    isActive,
    createdAt,
    createdBy,
    updatedBy,
    type,
    code,
    layoutConfig,
  ];
}
