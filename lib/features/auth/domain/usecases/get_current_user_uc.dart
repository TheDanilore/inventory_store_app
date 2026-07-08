import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/auth/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/auth/domain/repositories/auth_repository.dart';

@injectable
class GetCurrentUserUseCase implements UseCase<UserEntity, NoParams> {
  final IAuthRepository repository;
  GetCurrentUserUseCase(this.repository);

  @override
  Future<Either<Failure, UserEntity>> call(NoParams params) async {
    return repository.getCurrentUser();
  }
}
