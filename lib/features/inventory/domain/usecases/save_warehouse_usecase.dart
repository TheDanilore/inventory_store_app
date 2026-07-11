import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/warehouses_repository.dart';

@injectable
class SaveWarehouseUseCase {
  final WarehousesRepository repository;

  SaveWarehouseUseCase(this.repository);

  Future<void> call({
    WarehouseModel? existingWarehouse,
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
