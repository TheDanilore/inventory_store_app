import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/auth/domain/entities/user_entity.dart';

abstract class AuthRepository {
  /// Devuelve el usuario actual si hay sesión y el perfil está activo.
  Future<Either<Failure, UserEntity>> getCurrentUser();

  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, String>> register({
    required String email,
    required String password,
  });

  Future<Either<Failure, UserEntity>> createProfile({
    required String authUserId,
    required String email,
    required String fullName,
    required String role,
    required bool isActive,
  });

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, void>> resetPassword(String email);

  Future<Either<Failure, void>> changePassword(String newPassword);

  Future<Either<Failure, void>> deleteAccount(String password);

  Future<Either<Failure, UserEntity>> updateProfile({
    required UserEntity user,
    Uint8List? imageBytes,
  });
}
