import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/users/domain/repositories/users_repository.dart';

@injectable
class CreateUserUseCase {
  final UsersRepository repository;

  CreateUserUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String email,
    required String password,
    required String role,
    required String fullName,
    String? phone,
    required String documentType,
    String? documentNumber,
  }) async {
    return await repository.createUser(
      email: email,
      password: password,
      role: role,
      fullName: fullName,
      phone: phone,
      documentType: documentType,
      documentNumber: documentNumber,
    );
  }
}
