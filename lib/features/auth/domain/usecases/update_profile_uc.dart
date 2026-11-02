import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/auth/domain/entities/auth_user_entity.dart';
import 'package:inventory_store_app/features/auth/domain/repositories/auth_repository.dart';

class UpdateProfileParams {
  final AuthUserEntity user;
  final Uint8List? imageBytes;
  const UpdateProfileParams({required this.user, this.imageBytes});
}

@injectable
class UpdateProfileUseCase
    implements UseCase<AuthUserEntity, UpdateProfileParams> {
  final AuthRepository repository;
  UpdateProfileUseCase(this.repository);

  @override
  Future<Either<Failure, AuthUserEntity>> call(
    UpdateProfileParams params,
  ) async {
    return repository.updateProfile(
      user: params.user,
      imageBytes: params.imageBytes,
    );
  }
}
