import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/auth/domain/entities/permission_entity.dart';
import 'package:inventory_store_app/features/roles/domain/entities/role_with_permissions.dart';
import 'package:inventory_store_app/features/roles/domain/repositories/roles_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@LazySingleton(as: RolesRepository)
class RolesRepositoryImpl implements RolesRepository {
  final SupabaseClient _supabase;

  RolesRepositoryImpl(this._supabase);

  @override
  Future<Either<Failure, List<RoleWithPermissions>>> getRoles() async {
    try {
      final data = await _supabase
          .from('roles')
          .select('''
            id,
            name,
            description,
            created_at,
            role_permissions (
              permissions (
                code
              )
            ),
            user_roles (
              profile_id
            )
          ''')
          .order('name');

      final List<RoleWithPermissions> roles = [];
      for (final item in data as List) {
        final id = item['id']?.toString() ?? '';
        final name = item['name']?.toString() ?? '';
        final desc = item['description']?.toString();
        final createdAtStr = item['created_at']?.toString();
        final createdAt =
            createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

        // Parsear permisos
        final perms = <String>[];
        final rpList = item['role_permissions'] as List?;
        if (rpList != null) {
          for (final rp in rpList) {
            final pObj = rp['permissions'] as Map<String, dynamic>?;
            final code = pObj?['code']?.toString();
            if (code != null && code.isNotEmpty) {
              perms.add(code);
            }
          }
        }

        // Conteo de usuarios asignados
        final urList = item['user_roles'] as List?;
        final userCount = urList?.length ?? 0;

        roles.add(
          RoleWithPermissions(
            id: id,
            name: name,
            description: desc,
            createdAt: createdAt,
            permissions: perms,
            userCount: userCount,
          ),
        );
      }

      return Right(roles);
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'Error PostgREST en getRoles',
        tag: 'RolesRepositoryImpl',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error al cargar roles: ${e.message}'),
      );
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en getRoles',
        tag: 'RolesRepositoryImpl',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: 'Error inesperado: $e'));
    }
  }

  @override
  Future<Either<Failure, List<PermissionEntity>>> getAllPermissions() async {
    try {
      final data = await _supabase
          .from('permissions')
          .select('id, code, name, module')
          .order('module')
          .order('name');

      final list =
          (data as List)
              .map(
                (p) => PermissionEntity(
                  id: p['id']?.toString() ?? '',
                  code: p['code']?.toString() ?? '',
                  name: p['name']?.toString() ?? '',
                  module: p['module']?.toString() ?? 'General',
                ),
              )
              .toList();

      if (list.isEmpty) {
        // Fallback a catálogo en memoria si la tabla aún no se ha poblado
        return Right(
          AppPermissions.all.map((c) {
            return PermissionEntity(
              id: c,
              code: c,
              name: AppPermissions.getLabel(c),
              module: AppPermissions.getModule(c),
            );
          }).toList(),
        );
      }

      return Right(list);
    } catch (e) {
      // Fallback seguro a constantes
      return Right(
        AppPermissions.all.map((c) {
          return PermissionEntity(
            id: c,
            code: c,
            name: AppPermissions.getLabel(c),
            module: AppPermissions.getModule(c),
          );
        }).toList(),
      );
    }
  }

  @override
  Future<Either<Failure, RoleWithPermissions>> createRole({
    required String name,
    String? description,
    List<String> permissionCodes = const [],
  }) async {
    final cleanName = name.trim().toLowerCase().replaceAll(' ', '_');
    if (cleanName.isEmpty) {
      return Left(ServerFailure(message: 'El nombre del rol es obligatorio.'));
    }

    try {
      final inserted =
          await _supabase
              .from('roles')
              .insert({'name': cleanName, 'description': description?.trim()})
              .select('id, name, description, created_at')
              .single();

      final roleId = inserted['id']?.toString() ?? '';

      if (permissionCodes.isNotEmpty) {
        await syncRolePermissions(
          roleId: roleId,
          permissionCodes: permissionCodes,
        );
      }

      final createdAtStr = inserted['created_at']?.toString();
      final createdAt =
          createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

      return Right(
        RoleWithPermissions(
          id: roleId,
          name: cleanName,
          description: description?.trim(),
          createdAt: createdAt,
          permissions: permissionCodes,
          userCount: 0,
        ),
      );
    } on PostgrestException catch (e) {
      if (e.message.contains('unique') || e.code == '23505') {
        return Left(
          ServerFailure(message: 'Ya existe un rol con ese identificador.'),
        );
      }
      return Left(ServerFailure(message: 'Error al crear rol: ${e.message}'));
    } catch (e) {
      return Left(ServerFailure(message: 'Error al crear rol: $e'));
    }
  }

  @override
  Future<Either<Failure, RoleWithPermissions>> updateRole({
    required String id,
    required String name,
    String? description,
    List<String>? permissionCodes,
  }) async {
    final cleanName = name.trim().toLowerCase().replaceAll(' ', '_');
    if (cleanName.isEmpty) {
      return Left(ServerFailure(message: 'El nombre del rol es obligatorio.'));
    }

    try {
      final updated =
          await _supabase
              .from('roles')
              .update({'name': cleanName, 'description': description?.trim()})
              .eq('id', id)
              .select('id, name, description, created_at')
              .single();

      if (permissionCodes != null) {
        await syncRolePermissions(roleId: id, permissionCodes: permissionCodes);
      }

      final createdAtStr = updated['created_at']?.toString();
      final createdAt =
          createdAtStr != null ? DateTime.tryParse(createdAtStr) : null;

      return Right(
        RoleWithPermissions(
          id: id,
          name: cleanName,
          description: description?.trim(),
          createdAt: createdAt,
          permissions: permissionCodes ?? [],
        ),
      );
    } on PostgrestException catch (e) {
      return Left(
        ServerFailure(message: 'Error al actualizar rol: ${e.message}'),
      );
    } catch (e) {
      return Left(ServerFailure(message: 'Error al actualizar rol: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> syncRolePermissions({
    required String roleId,
    required List<String> permissionCodes,
  }) async {
    try {
      // 1. Eliminar asignaciones actuales
      await _supabase.from('role_permissions').delete().eq('role_id', roleId);

      if (permissionCodes.isEmpty) {
        return const Right(null);
      }

      // 2. Resolver IDs de los códigos de permisos
      final permsData = await _supabase
          .from('permissions')
          .select('id, code')
          .inFilter('code', permissionCodes);

      final inserts =
          (permsData as List).map((p) {
            return {'role_id': roleId, 'permission_id': p['id']};
          }).toList();

      if (inserts.isNotEmpty) {
        await _supabase.from('role_permissions').insert(inserts);
      }

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(
        ServerFailure(message: 'Error al sincronizar permisos: ${e.message}'),
      );
    } catch (e) {
      return Left(ServerFailure(message: 'Error al sincronizar permisos: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteRole(String id) async {
    try {
      // Verificar si es un rol protegido
      final role =
          await _supabase
              .from('roles')
              .select('name')
              .eq('id', id)
              .maybeSingle();

      final roleName = role?['name']?.toString() ?? '';
      if (roleName == 'admin' || roleName == 'customer') {
        return Left(
          ServerFailure(
            message:
                'No está permitido eliminar el rol de sistema "$roleName".',
          ),
        );
      }

      await _supabase.from('roles').delete().eq('id', id);
      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(
        ServerFailure(message: 'Error al eliminar rol: ${e.message}'),
      );
    } catch (e) {
      return Left(ServerFailure(message: 'Error al eliminar rol: $e'));
    }
  }
}
