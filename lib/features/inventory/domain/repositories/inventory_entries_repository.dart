import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_entry_item_entity.dart';

abstract class InventoryEntriesRepository {
  Future<void> createInventoryEntry({
    required List<InventoryEntryItemEntity> items,
    required String warehouseId,
    required String? supplierId,
    required String? purchaseOrderId,
    required String paymentMode,
    required String? accountId,
    required String? activeShiftId,
    required String documentType,
    required String? documentNumber,
    required DateTime? documentDate,
    required String notes,
  });

  Future<({List<InventoryEntryEntity> data, int count})> getEntries({
    required int start,
    required int end,
    String? searchQuery,
    String? warehouseFilter,
    DateTime? startDate,
    DateTime? endDate,
  });

  Future<List<dynamic>> getEntryItems(String entryId);
}
