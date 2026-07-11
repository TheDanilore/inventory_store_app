import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_entries_repository.dart';

@injectable
class GetActiveSuppliersUseCase {
  final InventoryEntriesRepository repository;

  GetActiveSuppliersUseCase(this.repository);

  Future<List<Map<String, dynamic>>> call() {
    return repository.getActiveSuppliers();
  }
}
