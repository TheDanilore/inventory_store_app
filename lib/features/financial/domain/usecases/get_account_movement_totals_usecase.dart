import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/account_movements_repository.dart';

@injectable
class GetAccountMovementTotalsUseCase {
  final AccountMovementsRepository _repository;

  GetAccountMovementTotalsUseCase(this._repository);

  Future<MovementTotals> call({required MovementFilters filters}) {
    return _repository.getMovementTotals(filters: filters);
  }
}
