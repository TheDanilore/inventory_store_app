import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/services/logger_service.dart';
import 'package:inventory_store_app/features/users/data/models/user_model.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/users/domain/repositories/users_repository.dart';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

@LazySingleton(as: UsersRepository)
class UsersRepositoryImpl implements UsersRepository {
  final SupabaseClient _supabase;

  UsersRepositoryImpl(this._supabase);

  Future<Map<String, List<String>>> _fetchUserRoles(
    List<String> profileIds,
  ) async {
    if (profileIds.isEmpty) return {};
    try {
      final res = await _supabase
          .from('user_roles')
          .select('profile_id, roles(name)')
          .filter('profile_id', 'in', '(${profileIds.join(',')})');
      final map = <String, List<String>>{};
      for (final item in res as List) {
        final pid = item['profile_id'] as String?;
        final rName = (item['roles'] as Map?)?['name']?.toString();
        if (pid != null && rName != null && rName.isNotEmpty) {
          map.putIfAbsent(pid, () => []).add(rName);
        }
      }
      return map;
    } catch (e) {
      developer.log(
        'Aviso: error obteniendo user_roles: $e',
        name: 'UsersRepositoryImpl',
      );
      return {};
    }
  }

  Future<void> _syncUserRoles(String profileId, List<String> roleNames) async {
    try {
      if (roleNames.isEmpty) return;
      // 1. Obtener los IDs de roles correspondientes a los nombres
      final rolesRes = await _supabase
          .from('roles')
          .select('id, name')
          .filter('name', 'in', '(${roleNames.join(',')})');

      final roleIds = <String>[];
      for (final r in rolesRes as List) {
        final rId = r['id']?.toString();
        if (rId != null) roleIds.add(rId);
      }

      // 2. Eliminar roles previos del perfil
      await _supabase.from('user_roles').delete().eq('profile_id', profileId);

      // 3. Insertar nuevos roles
      if (roleIds.isNotEmpty) {
        final rowsToInsert =
            roleIds
                .map((rid) => {'profile_id': profileId, 'role_id': rid})
                .toList();
        await _supabase.from('user_roles').insert(rowsToInsert);
      }
    } catch (e) {
      developer.log(
        'Aviso: error sincronizando user_roles: $e',
        name: 'UsersRepositoryImpl',
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getUsers({
    required String role,
    required String searchQuery,
    required bool onlyActive,
    required int page,
    required int pageSize,
  }) async {
    try {
      var query = _supabase
          .from('profiles_with_email')
          .select(
            'id, full_name, email, phone, role, is_active, '
            'document_type, document_number, wallet_balance, created_at',
          );

      if (role == 'staff' || role == 'all' || role.isEmpty) {
        query = query.neq('role', 'customer').neq('role', 'cliente');
      } else {
        query = query.eq('role', role);
      }

      if (onlyActive) {
        query = query.eq('is_active', true);
      }

      final term = searchQuery.trim();
      if (term.isNotEmpty) {
        query = query.or(
          'full_name.ilike.%$term%,phone.ilike.%$term%,document_number.ilike.%$term%,email.ilike.%$term%',
        );
      }

      final start = page * pageSize;
      final end = start + pageSize - 1;

      final response = await query
          .order('created_at', ascending: false)
          .range(start, end)
          .count(CountOption.exact);

      final List<UserEntity> rawUsers =
          (response.data as List)
              .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
              .toList();

      final ids = rawUsers.map((u) => u.id).toList();
      final rolesMap = await _fetchUserRoles(ids);

      final List<UserEntity> users =
          rawUsers.map((u) {
            final assignedRoles = rolesMap[u.id];
            if (assignedRoles != null && assignedRoles.isNotEmpty) {
              return u.copyWith(roles: assignedRoles);
            }
            return u;
          }).toList();

      return Right({'data': users, 'count': response.count});
    } on PostgrestException catch (e, st) {
      developer.log(
        '🔴 [UsersRepo] PostgrestException en getUsers (role=$role): $e',
        error: e,
        stackTrace: st,
        name: 'UsersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      developer.log(
        '🔴 [UsersRepo] Error en getUsers (role=$role): $e',
        error: e,
        stackTrace: st,
        name: 'UsersRepositoryImpl',
      );
      if (e.toString().toLowerCase().contains('socketexception')) {
        return Left(ServerFailure(message: 'Sin conexión a internet.'));
      }
      return Left(
        ServerFailure(message: 'Error al cargar usuarios: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, List<UserEntity>>> getAllUsers({
    required String role,
    required String searchQuery,
    required bool onlyActive,
  }) async {
    try {
      var query = _supabase
          .from('profiles_with_email')
          .select(
            'id, full_name, email, phone, role, is_active, '
            'document_type, document_number, wallet_balance, created_at',
          );

      if (role == 'staff' || role == 'all' || role.isEmpty) {
        query = query.neq('role', 'customer').neq('role', 'cliente');
      } else {
        query = query.eq('role', role);
      }

      if (onlyActive) {
        query = query.eq('is_active', true);
      }

      final term = searchQuery.trim().replaceAll(RegExp(r'[,"]'), '');
      if (term.isNotEmpty) {
        query = query.or(
          'full_name.ilike.%$term%,phone.ilike.%$term%,document_number.ilike.%$term%,email.ilike.%$term%',
        );
      }

      final response = await query.order('created_at', ascending: false);

      final List<UserEntity> rawUsers =
          (response as List)
              .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
              .toList();

      final ids = rawUsers.map((u) => u.id).toList();
      final rolesMap = await _fetchUserRoles(ids);

      final List<UserEntity> users =
          rawUsers.map((u) {
            final assignedRoles = rolesMap[u.id];
            if (assignedRoles != null && assignedRoles.isNotEmpty) {
              return u.copyWith(roles: assignedRoles);
            }
            return u;
          }).toList();

      return Right(users);
    } on PostgrestException catch (e, st) {
      developer.log(
        '🔴 [UsersRepo] PostgrestException en getAllUsers (role=$role): $e',
        error: e,
        stackTrace: st,
        name: 'UsersRepositoryImpl',
      );
      return Left(ServerFailure(message: e.message));
    } catch (e, st) {
      developer.log(
        '🔴 [UsersRepo] Excepción no controlada en getAllUsers: $e',
        error: e,
        stackTrace: st,
        name: 'UsersRepositoryImpl',
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, int>> getGlobalUsersCount({
    required String role,
  }) async {
    try {
      var query = _supabase
          .from('profiles_with_email')
          .count(CountOption.exact);

      if (role == 'staff' || role == 'all' || role.isEmpty) {
        query = query.neq('role', 'customer').neq('role', 'cliente');
      } else {
        query = query.eq('role', role);
      }

      final count = await query;
      return Right(count);
    } on PostgrestException catch (e, st) {
      developer.log(
        '🔴 [UsersRepo] PostgrestException en getGlobalUsersCount (role=$role): $e',
        error: e,
        stackTrace: st,
        name: 'UsersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      developer.log(
        '🔴 [UsersRepo] Error en getGlobalUsersCount (role=$role): $e',
        error: e,
        stackTrace: st,
        name: 'UsersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error al cargar conteo de usuarios.'),
      );
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getUserById(String id) async {
    try {
      final response =
          await _supabase
              .from('profiles_with_email')
              .select(
                'id, full_name, email, phone, role, is_active, '
                'document_type, document_number, wallet_balance, created_at',
              )
              .eq('id', id)
              .single();

      final user = UserModel.fromJson(response);
      final rolesMap = await _fetchUserRoles([id]);
      final assignedRoles = rolesMap[id];
      if (assignedRoles != null && assignedRoles.isNotEmpty) {
        return Right(user.copyWith(roles: assignedRoles));
      }

      return Right(user);
    } on PostgrestException catch (e, st) {
      developer.log(
        '🔴 [UsersRepo] PostgrestException en getUserById (id=$id): $e',
        error: e,
        stackTrace: st,
        name: 'UsersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      developer.log(
        '🔴 [UsersRepo] Error en getUserById (id=$id): $e',
        error: e,
        stackTrace: st,
        name: 'UsersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error al cargar detalles del usuario.'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> createUser({
    required String email,
    required String password,
    required String role,
    List<String>? roles,
    required String fullName,
    String? phone,
    required String documentType,
    String? documentNumber,
  }) async {
    try {
      final primaryRole =
          role.isNotEmpty ? role : (roles?.firstOrNull ?? 'employee');
      final response = await _supabase.functions.invoke(
        'crear-usuario-admin',
        body: {
          'email': email,
          'password': password,
          'role': primaryRole,
          'name': fullName,
          'phone': phone,
          'document_type': documentType,
          'document_number': documentNumber,
        },
      );

      if (response.status != 200) {
        return Left(
          ServerFailure(message: 'Error al crear usuario: ${response.data}'),
        );
      }

      // Sincronizar roles en user_roles si se especificaron
      if (roles != null && roles.isNotEmpty) {
        try {
          final profileData =
              await _supabase
                  .from('profiles_with_email')
                  .select('id')
                  .eq('email', email)
                  .maybeSingle();

          final profileId = profileData?['id']?.toString();
          if (profileId != null) {
            await _syncUserRoles(profileId, roles);
          }
        } catch (e) {
          developer.log('Aviso al asociar roles a nuevo usuario: $e');
        }
      }

      return const Right(null);
    } on PostgrestException catch (e, st) {
      developer.log(
        '🔴 [UsersRepo] PostgrestException en createUser: $e',
        error: e,
        stackTrace: st,
        name: 'UsersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      developer.log(
        '🔴 [UsersRepo] Error en createUser: $e',
        error: e,
        stackTrace: st,
        name: 'UsersRepositoryImpl',
      );
      if (e.toString().contains('already been registered')) {
        return Left(
          ServerFailure(
            message: 'Este correo ya está registrado en el sistema.',
          ),
        );
      }
      return Left(ServerFailure(message: 'Error al crear usuario.'));
    }
  }

  @override
  Future<Either<Failure, void>> updateUser({
    required String id,
    required String fullName,
    required String role,
    List<String>? roles,
    String? phone,
    required String documentType,
    String? documentNumber,
    required bool isActive,
    String? newPassword,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'full_name': fullName,
        'phone': phone,
        'document_type': documentType,
        'document_number': documentNumber,
        'is_active': isActive,
      };

      // Si se especificó rol o roles, sincronizamos también la columna de compatibilidad en profiles
      final primaryRole =
          (roles != null && roles.isNotEmpty)
              ? roles.first
              : (role.isNotEmpty ? role : null);
      if (primaryRole != null) {
        updateData['role'] = primaryRole;
      }

      await _supabase.from('profiles').update(updateData).eq('id', id);

      // Sincronizar roles en tabla relacional user_roles (fuente de verdad multi-rol)
      if (roles != null) {
        await _syncUserRoles(id, roles);
      }

      if (newPassword != null && newPassword.trim().isNotEmpty) {
        final passResponse = await _supabase.functions.invoke(
          'actualizar-password',
          body: {'user_id': id, 'new_password': newPassword.trim()},
        );

        if (passResponse.status != 200) {
          return Left(
            ServerFailure(
              message: 'Perfil actualizado pero falló la contraseña.',
            ),
          );
        }
      }

      return const Right(null);
    } on PostgrestException catch (e, st) {
      developer.log(
        '🔴 [UsersRepo] PostgrestException en updateUser (id=$id): $e',
        error: e,
        stackTrace: st,
        name: 'UsersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      developer.log(
        '🔴 [UsersRepo] Error en updateUser (id=$id): $e',
        error: e,
        stackTrace: st,
        name: 'UsersRepositoryImpl',
      );
      return Left(ServerFailure(message: 'Error al actualizar usuario.'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUser(String id) async {
    try {
      final response = await _supabase.rpc(
        'delete_user_force',
        params: {'p_user_id': id},
      );

      final Map<String, dynamic> result =
          response is Map<String, dynamic>
              ? response
              : Map<String, dynamic>.from(response as Map);

      final bool success = result['success'] == true;
      final String message =
          result['message']?.toString() ??
          'Error desconocido al eliminar usuario.';

      if (!success) {
        return Left(ServerFailure(message: message));
      }

      return const Right(null);
    } on PostgrestException catch (e, st) {
      LoggerService.e(
        'PostgrestException en deleteUser (id=$id): ${e.message}',
        tag: 'UsersRepo',
        error: e,
        stackTrace: st,
      );
      return Left(ServerFailure(message: e.message));
    } catch (e, st) {
      LoggerService.e(
        'Excepción no controlada en deleteUser (id=$id): $e',
        tag: 'UsersRepo',
        error: e,
        stackTrace: st,
      );
      return Left(
        ServerFailure(message: 'Error al eliminar usuario: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getUserRelations(String id) async {
    try {
      final res = await _supabase.rpc(
        'get_user_relations_summary',
        params: {'p_user_id': id},
      );
      final map = Map<String, dynamic>.from(res as Map);
      return Right(map.map((k, v) => MapEntry(k, (v as num).toInt())));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: 'Error al consultar relaciones: $e'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getRecentMovements(
    String userId,
  ) async {
    try {
      final res = await _supabase
          .from('wallet_movements')
          .select('id, points, movement_type, description, created_at')
          .eq('profile_id', userId)
          .order('created_at', ascending: false)
          .limit(5);

      return Right(List<Map<String, dynamic>>.from(res as List));
    } on PostgrestException catch (e, st) {
      developer.log(
        '🔴 [UsersRepo] PostgrestException en getRecentMovements (userId=$userId): $e',
        error: e,
        stackTrace: st,
        name: 'UsersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      developer.log(
        '🔴 [UsersRepo] Error en getRecentMovements (userId=$userId): $e',
        error: e,
        stackTrace: st,
        name: 'UsersRepositoryImpl',
      );
      return Left(ServerFailure(message: 'Error al cargar historial.'));
    }
  }

  @override
  Future<Either<Failure, int>> adjustPoints({
    required String userId,
    required int currentBalance,
    required int amount,
  }) async {
    try {
      // ✅ Operación 100% atómica: el RPC actualiza el saldo Y registra el
      // movimiento en una sola transacción PostgreSQL. Si falla cualquier
      // paso, Supabase ejecuta ROLLBACK automático — sin inconsistencias.
      final result = await _supabase.rpc(
        'rpc_adjust_wallet',
        params: {'p_user_id': userId, 'p_amount': amount},
      );

      final int newBalance = (result as num?)?.toInt() ?? currentBalance;
      return Right(newBalance);
    } on PostgrestException catch (e, st) {
      developer.log(
        '🔴 [UsersRepo] PostgrestException en adjustPoints (userId=$userId): $e',
        error: e,
        stackTrace: st,
        name: 'UsersRepositoryImpl',
      );
      return Left(
        ServerFailure(message: 'Error de base de datos: ${e.message}'),
      );
    } catch (e, st) {
      developer.log(
        '🔴 [UsersRepo] Error en adjustPoints (userId=$userId): $e',
        error: e,
        stackTrace: st,
        name: 'UsersRepositoryImpl',
      );
      return Left(ServerFailure(message: 'Error al actualizar saldo.'));
    }
  }
}
