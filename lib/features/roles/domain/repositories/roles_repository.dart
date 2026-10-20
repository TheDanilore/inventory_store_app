import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/auth/domain/entities/permission_entity.dart';
import 'package:inventory_store_app/features/roles/domain/entities/role_with_permissions.dart';

abstract class RolesRepository {
  /// Obtiene todos los roles registrados junto con sus códigos de permisos y cantidad de usuarios
  Future<Either<Failure, List<RoleWithPermissions>>> getRoles();

  /// Obtiene la lista completa de permisos existentes en el sistema
  Future<Either<Failure, List<PermissionEntity>>> getAllPermissions();

  /// Crea un nuevo rol y opcionalmente le asigna permisos iniciales
  Future<Either<Failure, RoleWithPermissions>> createRole({
    required String name,
    String? description,
    List<String> permissionCodes = const [],
  });

  /// Modifica los datos básicos del rol y sincroniza sus permisos asignados
  Future<Either<Failure, RoleWithPermissions>> updateRole({
    required String id,
    required String name,
    String? description,
    List<String>? permissionCodes,
  });

  /// Asigna de forma atómica la lista de permisos para un rol
  Future<Either<Failure, void>> syncRolePermissions({
    required String roleId,
    required List<String> permissionCodes,
  });

  /// Elimina un rol personalizado (protege roles del sistema como 'admin')
  Future<Either<Failure, void>> deleteRole(String id);
}
