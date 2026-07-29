import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_entries_repository.dart';

@injectable
class GetEntryItemsUseCase {
  final InventoryEntriesRepository repository;

  GetEntryItemsUseCase(this.repository);

  Future<List<dynamic>> call(String entryId) {
    return repository.getEntryItems(entryId);
  }
}
