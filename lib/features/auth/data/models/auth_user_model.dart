import 'package:inventory_store_app/features/auth/domain/entities/auth_user_entity.dart';

class AuthUserModel {
  /// `profiles.id` — UUID real del perfil (FK destino de wishlist, shopping_carts, etc.)
  final String id;

  /// `profiles.auth_user_id` — UUID de Supabase Auth (auth.users.id)
  final String authUserId;

  final String email;
  final String role;
  final String fullName;
  final String phone;
  final String documentType;
  final String documentNumber;
  final String? avatarUrl;
  final bool isActive;
  final List<String> roles;
  final Set<String> permissions;

  final String? warehouseId;
  final String? warehouseName;
  final DateTime? birthdate;

  const AuthUserModel({
    required this.id,
    required this.authUserId,
    required this.email,
    required this.role,
    required this.fullName,
    required this.phone,
    required this.documentType,
    required this.documentNumber,
    this.avatarUrl,
    required this.isActive,
    this.roles = const [],
    this.permissions = const {},
    this.warehouseId,
    this.warehouseName,
    this.birthdate,
  });

  factory AuthUserModel.fromMap(
    Map<String, dynamic> map,
    String email, {
    List<String>? userRoles,
    Set<String>? userPermissions,
  }) {
    final primaryRole = map['role']?.toString() ?? 'customer';

    // Parsear lista de roles
    final List<String> parsedRoles = [];
    if (userRoles != null && userRoles.isNotEmpty) {
      parsedRoles.addAll(userRoles);
    } else if (map['roles'] is List) {
      parsedRoles.addAll(
        (map['roles'] as List)
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty),
      );
    }
    if (!parsedRoles.contains(primaryRole)) {
      parsedRoles.add(primaryRole);
    }

    // Parsear permisos
    final Set<String> parsedPermissions = {};
    if (userPermissions != null) {
      parsedPermissions.addAll(userPermissions);
    } else if (map['permissions'] is Iterable) {
      parsedPermissions.addAll(
        (map['permissions'] as Iterable).map((e) => e.toString()),
      );
    }

    return AuthUserModel(
      id: map['id']?.toString() ?? '',
      authUserId: map['auth_user_id']?.toString() ?? '',
      email: email,
      role: primaryRole,
      fullName: map['full_name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      documentType: map['document_type']?.toString() ?? 'DNI',
      documentNumber: map['document_number']?.toString() ?? '',
      avatarUrl: map['avatar_url']?.toString(),
      isActive: map['is_active'] as bool? ?? true,
      roles: parsedRoles,
      permissions: parsedPermissions,
      warehouseId: map['warehouse_id']?.toString(),
      warehouseName: map['warehouse_name']?.toString(),
      birthdate:
          map['birthdate'] != null
              ? DateTime.tryParse(map['birthdate'].toString())
              : null,
    );
  }

  factory AuthUserModel.fromEntity(UserEntity entity) {
    return AuthUserModel(
      id: entity.id,
      authUserId: entity.authUserId,
      email: entity.email,
      role: entity.role,
      fullName: entity.fullName,
      phone: entity.phone,
      documentType: entity.documentType,
      documentNumber: entity.documentNumber,
      avatarUrl: entity.avatarUrl,
      isActive: entity.isActive,
      roles: entity.roles,
      permissions: entity.permissions,
      warehouseId: entity.warehouseId,
      warehouseName: entity.warehouseName,
      birthdate: entity.birthdate,
    );
  }

  UserEntity toEntity() {
    return UserEntity(
      id: id,
      authUserId: authUserId,
      email: email,
      role: role,
      fullName: fullName,
      phone: phone,
      documentType: documentType,
      documentNumber: documentNumber,
      avatarUrl: avatarUrl,
      isActive: isActive,
      roles: roles,
      permissions: permissions,
      warehouseId: warehouseId,
      warehouseName: warehouseName,
      birthdate: birthdate,
    );
  }
}

extension AuthUserModelCopyWith on AuthUserModel {
  AuthUserModel copyWith({
    String? avatarUrl,
    String? fullName,
    String? phone,
    String? documentNumber,
    List<String>? roles,
    Set<String>? permissions,
    String? warehouseId,
    String? warehouseName,
    DateTime? birthdate,
  }) {
    return AuthUserModel(
      id: id,
      authUserId: authUserId,
      email: email,
      role: role,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      documentType: documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      birthdate: birthdate ?? this.birthdate,
    );
  }
}
