import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/financial/domain/entities/account_movement_entity.dart';
import 'package:inventory_store_app/features/financial/domain/repositories/account_movements_repository.dart';

@injectable
class GetAccountMovementsUseCase {
  final AccountMovementsRepository _repository;

  GetAccountMovementsUseCase(this._repository);

  Future<List<AccountMovementEntity>> call({
    required MovementFilters filters,
    required int page,
    required int pageSize,
  }) {
    return _repository.getMovements(
      filters: filters,
      page: page,
      pageSize: pageSize,
    );
  }
}
