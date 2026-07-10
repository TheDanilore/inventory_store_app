import 'package:inventory_store_app/features/financial/domain/repositories/financial_accounts_repository.dart';

class SaveFinancialAccountUseCase {
  final FinancialAccountsRepository _repository;

  SaveFinancialAccountUseCase(this._repository);

  Future<void> call({
    String? accountId,
    required String name,
    required String type,
    required bool isActive,
    double? initialBalance,
  }) {
    return _repository.saveAccount(
      accountId: accountId,
      name: name,
      type: type,
      isActive: isActive,
      initialBalance: initialBalance,
    );
  }
}
