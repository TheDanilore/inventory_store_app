import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/account_movements_repository.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/financial_accounts_repository.dart';

@injectable
class TransferFundsUseCase {
  final AccountMovementsRepository _repository;
  final FinancialAccountsRepository _accountsRepository;

  TransferFundsUseCase(
    this._repository,
    this._accountsRepository,
  );

  Future<void> call({
    required String profileId,
    required String sourceAccountId,
    required String destAccountId,
    required double amount,
    required String description,
  }) async {
    if (amount <= 0) {
      throw Exception('El monto a transferir debe ser mayor a 0.');
    }

    if (sourceAccountId == destAccountId) {
      throw Exception('No puedes transferir a la misma cuenta.');
    }

    final sourceAccount = await _accountsRepository.getAccountById(sourceAccountId);
    if (sourceAccount == null) {
      throw Exception('La cuenta origen no existe.');
    }

    // Regla de Negocio: Validar saldo suficiente
    if (sourceAccount.balance < amount) {
      throw Exception('Fondos insuficientes. Saldo actual: .');
    }

    return _repository.transferFunds(
      profileId: profileId,
      sourceAccountId: sourceAccountId,
      destAccountId: destAccountId,
      amount: amount,
      description: description,
    );
  }
}
