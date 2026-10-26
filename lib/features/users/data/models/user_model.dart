import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    super.email,
    required super.fullName,
    required super.role,
    super.phone,
    required super.documentType,
    super.documentNumber,
    required super.isActive,
    super.createdAt,
    super.walletBalance,
    super.roles,
    super.warehouseId,
    super.warehouseName,
    super.birthdate,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final primaryRole = json['role'] as String? ?? 'customer';
    final List<String> parsedRoles = [];

    if (json['roles'] is List) {
      for (final r in json['roles'] as List) {
        final rName = r?.toString();
        if (rName != null && rName.isNotEmpty && !parsedRoles.contains(rName)) {
          parsedRoles.add(rName);
        }
      }
    } else if (json['user_roles'] is List) {
      for (final ur in json['user_roles'] as List) {
        if (ur is Map) {
          final roleObj = ur['roles'];
          if (roleObj is Map) {
            final rName = roleObj['name']?.toString();
            if (rName != null &&
                rName.isNotEmpty &&
                !parsedRoles.contains(rName)) {
              parsedRoles.add(rName);
            }
          }
        }
      }
    }

    if (!parsedRoles.contains(primaryRole) && primaryRole.isNotEmpty) {
      parsedRoles.add(primaryRole);
    }

    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String?,
      fullName: json['full_name'] as String? ?? 'Desconocido',
      role: primaryRole,
      phone: json['phone'] as String?,
      documentType: json['document_type'] as String? ?? 'DNI',
      documentNumber: json['document_number'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt:
          json['created_at'] != null
              ? DateTime.tryParse(json['created_at'])
              : null,
      walletBalance: json['wallet_balance'] as int? ?? 0,
      roles: parsedRoles,
      warehouseId: json['warehouse_id'] as String?,
      warehouseName: json['warehouse_name'] as String?,
      birthdate:
          json['birthdate'] != null
              ? DateTime.tryParse(json['birthdate'].toString())
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (email != null) 'email': email,
      'full_name': fullName,
      'role': role,
      if (phone != null) 'phone': phone,
      'document_type': documentType,
      if (documentNumber != null) 'document_number': documentNumber,
      'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'wallet_balance': walletBalance,
      'roles': roles,
      if (warehouseId != null) 'warehouse_id': warehouseId,
      if (warehouseName != null) 'warehouse_name': warehouseName,
      if (birthdate != null)
        'birthdate': birthdate!.toIso8601String().split('T').first,
    };
  }

  factory UserModel.fromEntity(UserEntity entity) {
    return UserModel(
      id: entity.id,
      email: entity.email,
      fullName: entity.fullName,
      role: entity.role,
      phone: entity.phone,
      documentType: entity.documentType,
      documentNumber: entity.documentNumber,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      walletBalance: entity.walletBalance,
      roles: entity.roles,
      warehouseId: entity.warehouseId,
      warehouseName: entity.warehouseName,
      birthdate: entity.birthdate,
    );
  }
}
