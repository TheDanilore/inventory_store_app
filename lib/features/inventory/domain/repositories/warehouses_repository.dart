import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';

abstract class WarehousesRepository {
  Future<Map<String, dynamic>> getWarehouses({
    required int start,
    required int end,
    String searchQuery = '',
  });

  Future<void> saveWarehouse({
    WarehouseModel? existingWarehouse,
    required String name,
    required String address,
    required bool isActive,
  });

  Future<void> toggleWarehouseStatus(WarehouseModel wh, bool isActive);
}
