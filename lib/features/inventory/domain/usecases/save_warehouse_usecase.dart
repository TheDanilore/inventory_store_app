import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/warehouses_repository.dart';

@injectable
class SaveWarehouseUseCase {
  final WarehousesRepository repository;

  SaveWarehouseUseCase(this.repository);

  Future<void> call({
    WarehouseEntity? existingWarehouse,
    required String name,
    required String address,
    required bool isActive,
  }) async {
    return repository.saveWarehouse(
      existingWarehouse: existingWarehouse,
      name: name,
      address: address,
      isActive: isActive,
    );
  }
}
