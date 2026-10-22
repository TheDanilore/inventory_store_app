import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';

class UserEntity extends Equatable {
  /// `profiles.id` — UUID real del perfil. Se usa como FK en wishlist, shopping_carts, etc.
  final String id;

  /// `profiles.auth_user_id` — UUID de Supabase Auth. Se usa para updateProfile, Auth operations.
  final String authUserId;

  final String email;
  final String role;
  final String fullName;
  final String phone;
  final String documentType;
  final String documentNumber;
  final String? avatarUrl;
  final bool isActive;

  /// Lista de roles asignados al usuario (Soporta múltiples roles vía `user_roles`)
  final List<String> roles;

  /// Conjunto de códigos de permisos efectivos asignados al usuario
  final Set<String> permissions;

  /// ID del almacén o sucursal por defecto asignado al usuario
  final String? warehouseId;

  /// Nombre del almacén asignado al usuario
  final String? warehouseName;

  const UserEntity({
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
  });

  /// Verifica si el usuario cuenta con un permiso específico.
  /// Se evalúan primero los permisos explícitos asignados; si es superusuario admin,
  /// tiene acceso total garantizado.
  bool hasPermission(String permissionCode) {
    if (permissions.contains(permissionCode)) return true;
    if (isAdmin) return true;
    return false;
  }

  /// Verifica si el usuario cuenta con al menos uno de los permisos indicados.
  bool hasAnyPermission(Iterable<String> permissionCodes) {
    if (isAdmin) return true;
    for (final code in permissionCodes) {
      if (permissions.contains(code)) return true;
    }
    return false;
  }

  /// Verifica si el usuario cuenta con todos los permisos indicados.
  bool hasAllPermissions(Iterable<String> permissionCodes) {
    if (isAdmin) return true;
    for (final code in permissionCodes) {
      if (!permissions.contains(code)) return false;
    }
    return true;
  }

  /// Verifica si el usuario posee un rol determinado (sea como rol primario o secundario).
  bool hasRole(String roleName) {
    if (role == roleName) return true;
    return roles.contains(roleName);
  }

  /// Helpers de roles frecuentes
  bool get isAdmin => role == AppRoles.admin || roles.contains(AppRoles.admin);
  bool get isCashier =>
      role == AppRoles.cashier || roles.contains(AppRoles.cashier);
  bool get isWarehouseKeeper =>
      role == AppRoles.warehouseKeeper ||
      roles.contains(AppRoles.warehouseKeeper);
  bool get isEmployee =>
      role == AppRoles.employee || roles.contains(AppRoles.employee);
  bool get isCustomer =>
      AppRoles.isCustomer(role) &&
      !isAdmin &&
      !isCashier &&
      !isWarehouseKeeper &&
      !isEmployee;

  @override
  List<Object?> get props => [
    id,
    authUserId,
    email,
    role,
    fullName,
    phone,
    documentType,
    documentNumber,
    avatarUrl,
    isActive,
    roles,
    permissions,
    warehouseId,
    warehouseName,
  ];

  UserEntity copyWith({
    String? id,
    String? authUserId,
    String? email,
    String? role,
    String? fullName,
    String? phone,
    String? documentType,
    String? documentNumber,
    String? avatarUrl,
    bool? isActive,
    List<String>? roles,
    Set<String>? permissions,
    String? warehouseId,
    String? warehouseName,
  }) {
    return UserEntity(
      id: id ?? this.id,
      authUserId: authUserId ?? this.authUserId,
      email: email ?? this.email,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      documentType: documentType ?? this.documentType,
      documentNumber: documentNumber ?? this.documentNumber,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      roles: roles ?? this.roles,
      permissions: permissions ?? this.permissions,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
    );
  }
}
