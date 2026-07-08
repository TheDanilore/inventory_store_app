import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/auth/domain/repositories/auth_repository.dart';

@injectable
class DeleteAccountUseCase implements UseCase<void, String> {
  final IAuthRepository repository;
  DeleteAccountUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String password) async {
    return repository.deleteAccount(password);
  }
}
