import 'package:equatable/equatable.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
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

  /// Fecha de nacimiento del usuario para felicitaciones y métricas
  final DateTime? birthdate;

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
    this.birthdate,
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

  /// Comprueba si el usuario tiene acceso operativo a ventas / POS
  bool get canAccessPos =>
      isAdmin ||
      hasAnyPermission([AppPermissions.posSale, AppPermissions.posView]);

  /// Comprueba si el usuario tiene acceso al entorno administrativo (ERP / Dashboard).
  ///
  /// DISEÑO RBAC: La decisión se toma **únicamente por permisos**, nunca por el nombre
  /// del rol. Los roles son agrupaciones de permisos; la autorización real siempre es
  /// "¿tiene el usuario el permiso X?"
  ///
  /// Evaluación en orden de prioridad:
  ///
  /// 1. Admin (isAdmin) → acceso total garantizado. Es el único chequeo de rol porque
  ///    el admin es un superusuario que por definición bypasea el sistema de permisos.
  /// 2. Permiso explícito `erp.access` → mecanismo principal y recomendado.
  ///    Si el rol tiene este permiso → accede al ERP. Si no → no accede.
  /// 3. Fallback de compatibilidad → para roles que aún no tienen `erp.access` en BD
  ///    pero tienen permisos estrictamente administrativos (products.create,
  ///    inventory.entries, purchases.view, etc.).
  ///    Nota: `customers.view`, `inventory.view` y `products.view` fueron retirados
  ///    del fallback porque el cajero también los necesita para operar en el POS.
  ///    El cajero no tiene ninguno de los permisos del fallback, por lo que
  ///    canAccessErp = false de forma natural, sin chequear nombres de roles.
  bool get canAccessErp {
    if (isAdmin) return true;

    // Permiso explícito: mecanismo principal
    if (hasPermission(AppPermissions.erpAccess)) return true;

    // Fallback de compatibilidad: permisos que solo tienen roles ERP (no cajero)
    return hasAnyPermission([
      AppPermissions.productsCreate,
      AppPermissions.productsEdit,
      AppPermissions.inventoryEntries,
      AppPermissions.inventoryExits,
      AppPermissions.inventoryKardex,
      AppPermissions.inventoryAdjust,
      AppPermissions.inventoryTransfer,
      AppPermissions.inventoryPhysicalCount,
      AppPermissions.purchasesView,
      AppPermissions.purchasesCreate,
      AppPermissions.purchasesReceive,
      AppPermissions.suppliersView,
      AppPermissions.suppliersManage,
      AppPermissions.reportsFinancial,
      AppPermissions.reportsSales,
      AppPermissions.reportsInventory,
      AppPermissions.reportsView,
      AppPermissions.usersView,
      AppPermissions.usersCreate,
      AppPermissions.rolesManage,
      AppPermissions.permissionsAssign,
      AppPermissions.settingsView,
      AppPermissions.settingsEdit,
      AppPermissions.warehousesManage,
      AppPermissions.warehousesViewAll,
      AppPermissions.financialAccountsManage,
      AppPermissions.financialMovementsCreate,
    ]);
  }

  /// Usuario asignado exclusivamente a POS/Caja (tiene permiso de POS pero no tiene acceso al ERP)
  bool get isPosOnly => canAccessPos && !canAccessErp;

  /// Determina si la fecha actual coincide con el día y mes de cumpleaños del usuario
  bool get isBirthdayToday {
    if (birthdate == null) return false;
    final now = DateTime.now();
    return birthdate!.month == now.month && birthdate!.day == now.day;
  }

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
    birthdate,
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
    DateTime? birthdate,
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
      birthdate: birthdate ?? this.birthdate,
    );
  }
}
