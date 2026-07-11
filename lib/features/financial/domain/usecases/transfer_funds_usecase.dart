import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/account_movements_repository.dart';

@injectable
class TransferFundsUseCase {
  final AccountMovementsRepository _repository;

  TransferFundsUseCase(this._repository);

  Future<void> call({
    required String profileId,
    required String sourceAccountId,
    required String destAccountId,
    required double amount,
    required String description,
  }) {
    return _repository.transferFunds(
      profileId: profileId,
      sourceAccountId: sourceAccountId,
      destAccountId: destAccountId,
      amount: amount,
      description: description,
    );
  }
}
