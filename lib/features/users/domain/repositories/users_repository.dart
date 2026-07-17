import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';

abstract class UsersRepository {
  Future<Either<Failure, List<UserEntity>>> getUsers({
    required String role,
    required String searchQuery,
    required bool onlyActive,
    required int page,
    required int pageSize,
  });

  Future<Either<Failure, int>> getGlobalUsersCount({
    required String role,
  });

  Future<Either<Failure, UserEntity>> getUserById(String id);

  Future<Either<Failure, void>> createUser({
    required String email,
    required String password,
    required String role,
    required String fullName,
    String? phone,
    required String documentType,
    String? documentNumber,
  });

  Future<Either<Failure, void>> updateUser({
    required String id,
    required String fullName,
    required String role,
    String? phone,
    required String documentType,
    String? documentNumber,
    required bool isActive,
    String? newPassword, // Opcional, si se quiere cambiar la contraseña
  });

  Future<Either<Failure, void>> deleteUser(String id);

  Future<Either<Failure, List<Map<String, dynamic>>>> getRecentMovements(String userId);

  Future<Either<Failure, int>> adjustPoints({
    required String userId,
    required int currentBalance,
    required int amount,
  });
}
