import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/warehouses_repository.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';

@injectable
class GetActiveWarehousesExitsUseCase {
  final WarehousesRepository repository;

  GetActiveWarehousesExitsUseCase(this.repository);

  Future<List<dynamic>> call() async {
    return repository.getActiveWarehouses();
  }
}
