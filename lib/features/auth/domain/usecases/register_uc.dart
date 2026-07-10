import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/auth/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:inventory_store_app/core/constants/app_roles.dart';

class RegisterParams {
  final String email;
  final String password;
  final String fullName;
  const RegisterParams({required this.email, required this.password, required this.fullName});
}

@injectable
class RegisterUseCase implements UseCase<UserEntity, RegisterParams> {
  final AuthRepository repository;
  RegisterUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(RegisterParams params) async {
    final registerResult = await repository.register(
      email: params.email,
      password: params.password,
    );

    return registerResult.fold(
      (failure) => left(failure),
      (authUserId) async {
        return await repository.createProfile(
          authUserId: authUserId,
          email: params.email,
          fullName: params.fullName,
          role: AppRoles.customer,
          isActive: true,
        );
      },
    );
  }
}
