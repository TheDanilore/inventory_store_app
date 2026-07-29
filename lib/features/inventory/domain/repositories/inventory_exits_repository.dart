import 'package:inventory_store_app/features/inventory/domain/entities/inventory_exit_entity.dart';

abstract class InventoryExitsRepository {
  Future<({List<InventoryExitEntity> data, int count})> getExits({
    required int start,
    required int end,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<dynamic>> getExitItems(String exitId);

  Future<List<dynamic>> getBatchesForVariant(
    String variantId,
    String warehouseId,
  );

  Future<void> saveExitTransaction({
    required String warehouseId,
    required String reason,
    required String? notes,
    required String? createdByProfileId,
    required List<dynamic> items,
  });
}
