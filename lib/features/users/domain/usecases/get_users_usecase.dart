import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/users/domain/entities/user_entity.dart';
import 'package:inventory_store_app/features/users/domain/repositories/users_repository.dart';

@injectable
class GetUsersUseCase {
  final UsersRepository repository;

  GetUsersUseCase(this.repository);

  Future<Either<Failure, List<UserEntity>>> call({
    required String role,
    required String searchQuery,
    required bool onlyActive,
    required int page,
    required int pageSize,
  }) async {
    return await repository.getUsers(
      role: role,
      searchQuery: searchQuery,
      onlyActive: onlyActive,
      page: page,
      pageSize: pageSize,
    );
  }
}
