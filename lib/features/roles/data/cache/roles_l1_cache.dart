import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/auth/domain/entities/permission_entity.dart';
import 'package:inventory_store_app/features/roles/domain/entities/role_with_permissions.dart';

/// L1 In-Memory Cache para el catálogo de roles y permisos.
/// Permite renderizado instantáneo en Frame 0 (Zero-Shimmer) y minimiza Egress en Supabase.
@lazySingleton
class RolesL1Cache {
  List<PermissionEntity>? _cachedPermissions;
  List<RoleWithPermissions>? _cachedRoles;
  DateTime? _lastPermissionsFetch;
  DateTime? _lastRolesFetch;

  /// TTL para catálogo de permisos (datos cuasi-estáticos).
  static const Duration permsTtl = Duration(hours: 4);

  /// TTL para roles y conteo de usuarios.
  static const Duration rolesTtl = Duration(minutes: 5);

  bool get hasValidPermissions =>
      _cachedPermissions != null &&
      _cachedPermissions!.isNotEmpty &&
      _lastPermissionsFetch != null &&
      DateTime.now().difference(_lastPermissionsFetch!) < permsTtl;

  bool get hasValidRoles =>
      _cachedRoles != null &&
      _cachedRoles!.isNotEmpty &&
      _lastRolesFetch != null &&
      DateTime.now().difference(_lastRolesFetch!) < rolesTtl;

  List<PermissionEntity>? get cachedPermissions => _cachedPermissions;
  List<RoleWithPermissions>? get cachedRoles => _cachedRoles;

  void setPermissions(List<PermissionEntity> permissions) {
    _cachedPermissions = List.unmodifiable(permissions);
    _lastPermissionsFetch = DateTime.now();
  }

  void setRoles(List<RoleWithPermissions> roles) {
    _cachedRoles = List.unmodifiable(roles);
    _lastRolesFetch = DateTime.now();
  }

  void invalidateRoles() {
    _cachedRoles = null;
    _lastRolesFetch = null;
  }

  void invalidateAll() {
    _cachedPermissions = null;
    _cachedRoles = null;
    _lastPermissionsFetch = null;
    _lastRolesFetch = null;
  }
}
