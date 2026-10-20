import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/users/domain/repositories/users_repository.dart';

@injectable
class GetUserRelationsUseCase {
  final UsersRepository repository;
  GetUserRelationsUseCase(this.repository);

  Future<Either<Failure, Map<String, int>>> call(String id) =>
      repository.getUserRelations(id);
}
