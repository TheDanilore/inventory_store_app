import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_exits_repository.dart';

@injectable
class GetActiveWarehousesExitsUseCase {
  final InventoryExitsRepository repository;

  GetActiveWarehousesExitsUseCase(this.repository);

  Future<List<dynamic>> call() async {
    return repository.getActiveWarehouses();
  }
}
