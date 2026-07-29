import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/users/domain/repositories/users_repository.dart';

@injectable
class GetGlobalUsersCountUseCase {
  final UsersRepository repository;

  GetGlobalUsersCountUseCase(this.repository);

  Future<Either<Failure, int>> call({required String role}) async {
    return await repository.getGlobalUsersCount(role: role);
  }
}
