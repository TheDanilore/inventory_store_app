import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_layout_config.dart';

abstract class WarehousesRepository {
  Future<List<WarehouseEntity>> getActiveWarehouses();

  Future<({List<WarehouseEntity> data, int count})> getWarehouses({
    required int start,
    required int end,
    String searchQuery = '',
  });

  Future<void> saveWarehouse({
    WarehouseEntity? existingWarehouse,
    required String name,
    required String address,
    required bool isActive,
    String type = 'warehouse',
    String? code,
    WarehouseLayoutConfig? layoutConfig,
  });

  Future<void> updateWarehouseLayout(
    String warehouseId,
    WarehouseLayoutConfig layoutConfig,
  );

  Future<void> toggleWarehouseStatus(WarehouseEntity wh, bool isActive);

  Future<void> deleteWarehouse(String id);
}
