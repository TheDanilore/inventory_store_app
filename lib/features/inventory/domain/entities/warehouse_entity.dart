import 'package:equatable/equatable.dart';

class WarehouseEntity extends Equatable {
  final String id;
  final String name;
  final String? address;
  final bool isActive;
  final DateTime? createdAt;
  final String? createdBy;
  final String? updatedBy;

  const WarehouseEntity({
    required this.id,
    required this.name,
    this.address,
    required this.isActive,
    this.createdAt,
    this.createdBy,
    this.updatedBy,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    isActive,
    createdAt,
    createdBy,
    updatedBy,
  ];
}
