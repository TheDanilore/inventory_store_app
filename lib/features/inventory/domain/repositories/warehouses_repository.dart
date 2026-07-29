import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';

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
  });

  Future<void> toggleWarehouseStatus(WarehouseEntity wh, bool isActive);
}
