import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/constants/app_permissions.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/auth/domain/entities/permission_entity.dart';
import 'package:inventory_store_app/features/roles/data/cache/roles_l1_cache.dart';
import 'package:inventory_store_app/features/roles/domain/entities/role_with_permissions.dart';
import 'package:inventory_store_app/features/roles/domain/repositories/roles_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@LazySingleton(as: RolesRepository)
class RolesRepositoryImpl implements RolesRepository {
  final SupabaseClient _supabase;
  final RolesL1Cache _cache;

  RolesRepositoryImpl(this._supabase, [RolesL1Cache? cache])
    : _cache = cache ?? RolesL1Cache();

  @override
  List<PermissionEntity>? get cachedPermissions => _cache.cachedPermissions;

  @override
  List<RoleWithPermissions>? get cachedRoles => _cache.cachedRoles;

  @override
  void invalidateRolesCache() {
    _cache.invalidateRoles();
  }

  @override
  Future<Either<Failure, List<RoleWithPermissions>>> getRoles({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache.hasValidRoles) {
      return Right(_cache.cachedRoles!);
    }

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

        // Parsear códigos de permisos asociados
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

        // Conteo de usuarios asignados al rol
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

      // Guardar en caché L1
      _cache.setRoles(roles);

      return Right(roles);
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'Error PostgREST en getRoles',
        tag: 'RolesRepositoryImpl',
        error: e,
        stackTrace: st,
      );
      // Fallback a caché stale si existe
      if (_cache.cachedRoles != null && _cache.cachedRoles!.isNotEmpty) {
        return Right(_cache.cachedRoles!);
      }
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
      if (_cache.cachedRoles != null && _cache.cachedRoles!.isNotEmpty) {
        return Right(_cache.cachedRoles!);
      }
      return Left(ServerFailure(message: 'Error inesperado: $e'));
    }
  }

  @override
  Future<Either<Failure, List<PermissionEntity>>> getAllPermissions({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache.hasValidPermissions) {
      return Right(_cache.cachedPermissions!);
    }

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
        // Fallback a catálogo en memoria local si la tabla no contiene filas
        final fallback = _buildLocalFallbackPermissions();
        _cache.setPermissions(fallback);
        return Right(fallback);
      }

      _cache.setPermissions(list);
      return Right(list);
    } catch (e, st) {
      LoggerService.w(
        'Error al obtener permisos de Supabase, usando catálogo local',
        tag: 'RolesRepositoryImpl',
        error: e,
        stackTrace: st,
      );
      final fallback =
          _cache.cachedPermissions ?? _buildLocalFallbackPermissions();
      _cache.setPermissions(fallback);
      return Right(fallback);
    }
  }

  List<PermissionEntity> _buildLocalFallbackPermissions() {
    return AppPermissions.all.map((c) {
      return PermissionEntity(
        id: c,
        code: c,
        name: AppPermissions.getLabel(c),
        module: AppPermissions.getModule(c),
      );
    }).toList();
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

      _cache.invalidateRoles();

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
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'Error PostgREST en createRole',
        tag: 'RolesRepositoryImpl',
        error: e,
        stackTrace: st,
      );
      if (e.message.contains('unique') || e.code == '23505') {
        return Left(
          ServerFailure(message: 'Ya existe un rol con ese identificador.'),
        );
      }
      return Left(ServerFailure(message: 'Error al crear rol: ${e.message}'));
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en createRole',
        tag: 'RolesRepositoryImpl',
        error: e,
        stackTrace: st,
      );
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

      _cache.invalidateRoles();

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
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'Error PostgREST en updateRole',
        tag: 'RolesRepositoryImpl',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error al actualizar rol: ${e.message}'),
      );
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en updateRole',
        tag: 'RolesRepositoryImpl',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: 'Error al actualizar rol: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> syncRolePermissions({
    required String roleId,
    required List<String> permissionCodes,
  }) async {
    try {
      // 1. Intento transaccional atómico vía RPC en Supabase
      try {
        await _supabase.rpc(
          'sync_role_permissions_atomic',
          params: {'p_role_id': roleId, 'p_permission_codes': permissionCodes},
        );
        _cache.invalidateRoles();
        return const Right(null);
      } on PostgrestException catch (rpcError) {
        // Si el RPC no existe aún en la base de datos (código 42883 o PGRST202), ejecutamos fallback controlado
        if (rpcError.code == '42883' ||
            rpcError.code == 'PGRST202' ||
            rpcError.message.contains('function') ||
            rpcError.message.contains('not found')) {
          LoggerService.w(
            'RPC sync_role_permissions_atomic no encontrado, usando fallback seguro',
            tag: 'RolesRepositoryImpl',
          );
          return await _syncRolePermissionsFallback(roleId, permissionCodes);
        }
        rethrow;
      }
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'Error PostgREST en syncRolePermissions',
        tag: 'RolesRepositoryImpl',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error al sincronizar permisos: ${e.message}'),
      );
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en syncRolePermissions',
        tag: 'RolesRepositoryImpl',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: 'Error al sincronizar permisos: $e'));
    }
  }

  /// Fallback controlado cuando el RPC aún no está creado en PostgreSQL
  Future<Either<Failure, void>> _syncRolePermissionsFallback(
    String roleId,
    List<String> permissionCodes,
  ) async {
    // 1. Resolver IDs antes de borrar para minimizar ventana de vulnerabilidad
    List<dynamic> inserts = [];
    if (permissionCodes.isNotEmpty) {
      final permsData = await _supabase
          .from('permissions')
          .select('id, code')
          .inFilter('code', permissionCodes);

      inserts =
          (permsData as List).map((p) {
            return {'role_id': roleId, 'permission_id': p['id']};
          }).toList();
    }

    // 2. Eliminar asignaciones actuales
    await _supabase.from('role_permissions').delete().eq('role_id', roleId);

    // 3. Insertar nuevas
    if (inserts.isNotEmpty) {
      await _supabase.from('role_permissions').insert(inserts);
    }

    _cache.invalidateRoles();
    return const Right(null);
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
      _cache.invalidateRoles();
      return const Right(null);
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'Error PostgREST en deleteRole',
        tag: 'RolesRepositoryImpl',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error al eliminar rol: ${e.message}'),
      );
    } catch (e, st) {
      LoggerService.e(
        'Error inesperado en deleteRole',
        tag: 'RolesRepositoryImpl',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: 'Error al eliminar rol: $e'));
    }
  }
}
