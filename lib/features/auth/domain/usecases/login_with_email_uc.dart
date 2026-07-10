import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/auth/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/auth/domain/repositories/auth_repository.dart';

class LoginParams {
  final String email;
  final String password;
  const LoginParams({required this.email, required this.password});
}

@injectable
class LoginWithEmailUseCase implements UseCase<UserEntity, LoginParams> {
  final AuthRepository repository;
  LoginWithEmailUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(LoginParams params) async {
    final result = await repository.login(email: params.email, password: params.password);
    return result.fold(
      (failure) => left(failure),
      (user) async {
        if (!user.isActive) {
          await repository.logout();
          return left(Failure.from('Tu cuenta está inactiva o bloqueada.'));
        }
        return right(user);
      },
    );
  }
}
