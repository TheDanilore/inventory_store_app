import 'package:inventory_store_app/features/financial/domain/repositories/account_movements_repository.dart';

class SaveAccountMovementUseCase {
  final AccountMovementsRepository _repository;

  SaveAccountMovementUseCase(this._repository);

  Future<void> call({
    required String accountId,
    required String movementType,
    required double amount,
    required String description,
    String? referenceType,
    String? referenceId,
  }) {
    return _repository.saveMovement(
      accountId: accountId,
      movementType: movementType,
      amount: amount,
      description: description,
      referenceType: referenceType,
      referenceId: referenceId,
    );
  }
}
