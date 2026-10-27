import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_layout_config.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/warehouses_repository.dart';

@injectable
class SaveWarehouseLayoutUseCase {
  final WarehousesRepository repository;

  SaveWarehouseLayoutUseCase(this.repository);

  Future<void> call(
    String warehouseId,
    WarehouseLayoutConfig layoutConfig,
  ) async {
    return repository.updateWarehouseLayout(warehouseId, layoutConfig);
  }
}
