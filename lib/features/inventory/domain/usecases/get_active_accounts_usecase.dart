import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_entries_repository.dart';

@injectable
class GetActiveAccountsUseCase {
  final InventoryEntriesRepository repository;

  GetActiveAccountsUseCase(this.repository);

  Future<List<Map<String, dynamic>>> call() {
    return repository.getActiveAccounts();
  }
}
