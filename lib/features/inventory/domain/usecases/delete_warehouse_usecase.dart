import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/warehouses_repository.dart';

@injectable
class DeleteWarehouseUseCase {
  final WarehousesRepository repository;

  DeleteWarehouseUseCase(this.repository);

  Future<void> call(String id) async {
    return repository.deleteWarehouse(id);
  }
}
