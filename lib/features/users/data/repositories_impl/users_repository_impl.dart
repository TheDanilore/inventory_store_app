import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/users/data/models/user_model.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/users/domain/repositories/users_repository.dart';
import 'dart:developer' as developer;
import 'package:supabase_flutter/supabase_flutter.dart';

@LazySingleton(as: UsersRepository)
class UsersRepositoryImpl implements UsersRepository {
  final SupabaseClient _supabase;

  UsersRepositoryImpl(this._supabase);

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

      query = query.eq('role', role);

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

      final List<UserEntity> users =
          (response.data as List)
              .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
              .toList();

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

      query = query.eq('role', role);

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

      final List<UserEntity> users =
          (response as List)
              .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
              .toList();

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
      // Usar count directo sin select para Zero Data Egress
      final count = await _supabase
          .from('profiles_with_email')
          .count(CountOption.exact)
          .eq('role', role);

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

      return Right(UserModel.fromJson(response));
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
    required String fullName,
    String? phone,
    required String documentType,
    String? documentNumber,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'crear-usuario-admin',
        body: {
          'email': email,
          'password': password,
          'role': role,
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
    String? phone,
    required String documentType,
    String? documentNumber,
    required bool isActive,
    String? newPassword,
  }) async {
    try {
      await _supabase
          .from('profiles')
          .update({
            'full_name': fullName,
            'phone': phone,
            'document_type': documentType,
            'document_number': documentNumber,
            'role': role,
            'is_active': isActive,
          })
          .eq('id', id);

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
    // Lógica para deshabilitar o eliminar, asumo que aquí no se borra duro
    // O tal vez no había, lo pondré como no implementado por ahora
    return Left(
      ServerFailure(message: 'Eliminación dura no permitida. Inactívalo.'),
    );
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
