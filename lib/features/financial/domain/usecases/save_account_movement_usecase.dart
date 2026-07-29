import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/account_movements_repository.dart';

@injectable
class SaveAccountMovementUseCase {
  final AccountMovementsRepository _repository;

  SaveAccountMovementUseCase(this._repository);

  Future<void> call({
    required String profileId,
    required String accountId,
    required String movementType,
    required double amount,
    required String description,
  }) {
    return _repository.registerManualMovement(
      profileId: profileId,
      accountId: accountId,
      movementType: movementType,
      amount: amount,
      description: description,
    );
  }
}
