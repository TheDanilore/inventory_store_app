import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/warehouses_repository.dart';

@injectable
class GetActiveWarehousesExitsUseCase {
  final WarehousesRepository repository;

  GetActiveWarehousesExitsUseCase(this.repository);

  Future<List<WarehouseEntity>> call() {
    return repository.getActiveWarehouses();
  }
}
