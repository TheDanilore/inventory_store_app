import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/warehouses_repository.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';

@injectable
class GetWarehousesUseCase {
  final WarehousesRepository repository;

  GetWarehousesUseCase(this.repository);

  Future<({List<WarehouseEntity> data, int count})> call({
    required int start,
    required int end,
    String searchQuery = '',
  }) async {
    return repository.getWarehouses(
      start: start,
      end: end,
      searchQuery: searchQuery,
    );
  }
}
