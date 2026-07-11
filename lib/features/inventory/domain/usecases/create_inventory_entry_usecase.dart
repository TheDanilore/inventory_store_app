import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/data/models/entry_item_ui.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_entries_repository.dart';

@injectable
class CreateInventoryEntryUseCase {
  final InventoryEntriesRepository repository;

  CreateInventoryEntryUseCase(this.repository);

  Future<void> call({
    required List<EntryItemUI> items,
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
  }) {
    return repository.createInventoryEntry(
      items: items,
      warehouseId: warehouseId,
      supplierId: supplierId,
      purchaseOrderId: purchaseOrderId,
      paymentMode: paymentMode,
      accountId: accountId,
      activeShiftId: activeShiftId,
      documentType: documentType,
      documentNumber: documentNumber,
      documentDate: documentDate,
      notes: notes,
    );
  }
}
