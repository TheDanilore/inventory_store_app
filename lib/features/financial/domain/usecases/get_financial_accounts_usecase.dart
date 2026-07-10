import 'package:inventory_store_app/features/financial/domain/entities/financial_account_entity.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/financial_accounts_repository.dart';

class GetFinancialAccountsUseCase {
  final FinancialAccountsRepository _repository;

  GetFinancialAccountsUseCase(this._repository);

  Future<List<FinancialAccountEntity>> call({
    required int page,
    required int pageSize,
  }) {
    return _repository.getAccounts(page: page, pageSize: pageSize);
  }
}
