import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String? email;
  final String fullName;
  final String role;
  final String? phone;
  final String documentType;
  final String? documentNumber;
  final bool isActive;
  final DateTime? createdAt;
  final int walletBalance;
  final List<String> roles;
  final String? warehouseId;
  final String? warehouseName;

  const UserEntity({
    required this.id,
    this.email,
    required this.fullName,
    required this.role,
    this.phone,
    required this.documentType,
    this.documentNumber,
    required this.isActive,
    this.createdAt,
    this.walletBalance = 0,
    this.roles = const [],
    this.warehouseId,
    this.warehouseName,
  });

  /// Lista de todos los roles asignados, incluyendo el rol primario
  List<String> get allRoles {
    final list = <String>[];
    if (role.isNotEmpty) list.add(role);
    for (final r in roles) {
      if (!list.contains(r)) list.add(r);
    }
    return list;
  }

  @override
  List<Object?> get props => [
    id,
    email,
    fullName,
    role,
    phone,
    documentType,
    documentNumber,
    isActive,
    createdAt,
    walletBalance,
    roles,
    warehouseId,
    warehouseName,
  ];

  UserEntity copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? phone,
    String? documentType,
    String? documentNumber,
    bool? isActive,
    DateTime? createdAt,
    int? walletBalance,
    List<String>? roles,
    String? warehouseId,
    String? warehouseName,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      walletBalance: walletBalance ?? this.walletBalance,
      roles: roles ?? this.roles,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
    );
  }
}
