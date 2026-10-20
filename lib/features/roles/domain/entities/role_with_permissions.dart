import 'package:equatable/equatable.dart';

class RoleWithPermissions extends Equatable {
  final String id;
  final String name;
  final String? description;
  final DateTime? createdAt;
  final List<String> permissions;
  final int userCount;

  const RoleWithPermissions({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
    this.permissions = const [],
    this.userCount = 0,
  });

  bool get isSystemRole =>
      name == 'admin' ||
      name == 'cashier' ||
      name == 'warehouse_keeper' ||
      name == 'employee' ||
      name == 'customer';

  RoleWithPermissions copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    List<String>? permissions,
    int? userCount,
  }) {
    return RoleWithPermissions(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      permissions: permissions ?? this.permissions,
      userCount: userCount ?? this.userCount,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    description,
    createdAt,
    permissions,
    userCount,
  ];
}
