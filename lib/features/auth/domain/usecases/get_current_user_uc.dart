import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/auth/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/auth/domain/repositories/auth_repository.dart';

@injectable
class GetCurrentUserUseCase implements UseCase<UserEntity, NoParams> {
  final AuthRepository repository;
  GetCurrentUserUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(NoParams params) async {
    final result = await repository.getCurrentUser();

    return result.fold(
      (failure) async {
        return left(failure);
      },
      (user) async {
        if (!user.isActive) {
          await repository.logout();
          return left(
            const ValidationFailure(
              message:
                  'Tu cuenta está inactiva o bloqueada. Contacta al administrador.',
            ),
          );
        }
        return right(user);
      },
    );
  }
}
