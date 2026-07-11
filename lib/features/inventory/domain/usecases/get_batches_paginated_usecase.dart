import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_repository.dart';

@injectable
class GetBatchesPaginatedUseCase {
  final InventoryRepository _repository;

  GetBatchesPaginatedUseCase(this._repository);

  Future<List<InventoryBatchItem>> call({
    required int page,
    required int pageSize,
    String search = '',
    String statusFilter = 'Todos',
  }) {
    return _repository.getBatchesPaginated(
      page: page,
      pageSize: pageSize,
      search: search,
      statusFilter: statusFilter,
    );
  }

  Future<int> getTotalCount({
    String search = '',
    String statusFilter = 'Todos',
  }) {
    return _repository.getTotalBatchesCount(
      search: search,
      statusFilter: statusFilter,
    );
  }
}
