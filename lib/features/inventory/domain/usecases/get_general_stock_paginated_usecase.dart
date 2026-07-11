import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_stock_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_repository.dart';

@injectable
class GetGeneralStockPaginatedUseCase {
  final InventoryRepository _repository;

  GetGeneralStockPaginatedUseCase(this._repository);

  Future<List<InventoryStockItem>> call({
    required int page,
    required int pageSize,
    String search = '',
    String categoryName = 'Todos',
  }) {
    return _repository.getGeneralStockPaginated(
      page: page,
      pageSize: pageSize,
      search: search,
      categoryName: categoryName,
    );
  }

  Future<int> getTotalCount({
    String search = '',
    String categoryName = 'Todos',
  }) {
    return _repository.getTotalGeneralStockCount(
      search: search,
      categoryName: categoryName,
    );
  }
}
