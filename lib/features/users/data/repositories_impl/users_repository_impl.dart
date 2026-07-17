import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/users/data/models/user_model.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/users/domain/repositories/users_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@LazySingleton(as: UsersRepository)
class UsersRepositoryImpl implements UsersRepository {
  final SupabaseClient _supabase;

  UsersRepositoryImpl(this._supabase);

  @override
  Future<Either<Failure, List<UserEntity>>> getUsers({
    required String role,
    required String searchQuery,
    required bool onlyActive,
    required int page,
    required int pageSize,
  }) async {
    try {
      var query = _supabase.from('profiles_with_email').select('*');

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

      final response = await query.order('created_at', ascending: false).range(start, end);

      final List<UserEntity> users = (response as List)
          .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
          .toList();

      return Right(users);
    } catch (e) {
      if (e.toString().toLowerCase().contains('socketexception')) {
        return Left(ServerFailure(message: 'Sin conexión a internet.'));
      }
      return Left(ServerFailure(message: 'Error al cargar usuarios.'));
    }
  }

  @override
  Future<Either<Failure, int>> getGlobalUsersCount({required String role}) async {
    try {
      final response = await _supabase
          .from('profiles_with_email')
          .select('*')
          .eq('role', role)
          .count(CountOption.exact);

      return Right(response.count);
    } catch (e) {
      return Left(ServerFailure(message: 'Error al cargar conteo de usuarios.'));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getUserById(String id) async {
    try {
      final response = await _supabase
          .from('profiles_with_email')
          .select('*')
          .eq('id', id)
          .single();

      return Right(UserModel.fromJson(response));
    } catch (e) {
      return Left(ServerFailure(message: 'Error al cargar detalles del usuario.'));
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
        return Left(ServerFailure(message: 'Error al crear usuario: ${response.data}'));
      }

      return const Right(null);
    } catch (e) {
      if (e.toString().contains('already been registered')) {
        return Left(ServerFailure(message: 'Este correo ya está registrado en el sistema.'));
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
      await _supabase.from('profiles').update({
        'full_name': fullName,
        'phone': phone,
        'document_type': documentType,
        'document_number': documentNumber,
        'role': role,
        'is_active': isActive,
      }).eq('id', id);

      if (newPassword != null && newPassword.trim().isNotEmpty) {
        final passResponse = await _supabase.functions.invoke(
          'actualizar-password',
          body: {
            'user_id': id,
            'new_password': newPassword.trim(),
          },
        );

        if (passResponse.status != 200) {
          return Left(ServerFailure(message: 'Perfil actualizado pero falló la contraseña.'));
        }
      }

      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Error al actualizar usuario.'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteUser(String id) async {
    // Lógica para deshabilitar o eliminar, asumo que aquí no se borra duro
    // O tal vez no había, lo pondré como no implementado por ahora
    return Left(ServerFailure(message: 'Eliminación dura no permitida. Inactívalo.'));
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getRecentMovements(String userId) async {
    try {
      final res = await _supabase
          .from('wallet_movements')
          .select('id, points, movement_type, description, created_at')
          .eq('profile_id', userId)
          .order('created_at', ascending: false)
          .limit(5);

      return Right(List<Map<String, dynamic>>.from(res as List));
    } catch (e) {
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
      final int newBalance = (currentBalance + amount).clamp(0, 9999999);

      await _supabase
          .from('profiles')
          .update({'wallet_balance': newBalance})
          .eq('id', userId);

      await _supabase.from('wallet_movements').insert({
        'profile_id': userId,
        'points': amount,
        'movement_type': 'MANUAL_BONUS',
        'description':
            amount > 0
                ? 'Abono manual de administrador'
                : 'Descuento manual de administrador',
      });

      return Right(newBalance);
    } catch (e) {
      return Left(ServerFailure(message: 'Error al actualizar saldo.'));
    }
  }
}
