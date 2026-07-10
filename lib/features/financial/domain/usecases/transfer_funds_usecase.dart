import 'package:inventory_store_app/features/financial/domain/repositories/account_movements_repository.dart';

class TransferFundsUseCase {
  final AccountMovementsRepository _repository;

  TransferFundsUseCase(this._repository);

  Future<void> call({
    required String sourceAccountId,
    required String destAccountId,
    required double amount,
    required String description,
  }) {
    return _repository.transferFunds(
      sourceAccountId: sourceAccountId,
      destAccountId: destAccountId,
      amount: amount,
      description: description,
    );
  }
}
