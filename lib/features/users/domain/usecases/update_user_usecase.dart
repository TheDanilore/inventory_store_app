import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/users/domain/repositories/users_repository.dart';

@injectable
class UpdateUserUseCase {
  final UsersRepository repository;

  UpdateUserUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String id,
    required String fullName,
    required String role,
    String? phone,
    required String documentType,
    String? documentNumber,
    required bool isActive,
    String? newPassword,
  }) async {
    return await repository.updateUser(
      id: id,
      fullName: fullName,
      role: role,
      phone: phone,
      documentType: documentType,
      documentNumber: documentNumber,
      isActive: isActive,
      newPassword: newPassword,
    );
  }
}
