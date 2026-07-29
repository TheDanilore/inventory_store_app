import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/warehouses_repository.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';

@injectable
class GetActiveWarehousesUseCase {
  final WarehousesRepository repository;

  GetActiveWarehousesUseCase(this.repository);

  Future<List<WarehouseEntity>> call() {
    return repository.getActiveWarehouses();
  }
}
