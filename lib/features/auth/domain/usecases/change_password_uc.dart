import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/auth/domain/repositories/auth_repository.dart';

@injectable
class ChangePasswordUseCase implements UseCase<void, String> {
  final AuthRepository repository;
  ChangePasswordUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String newPassword) async {
    return repository.changePassword(newPassword);
  }
}
