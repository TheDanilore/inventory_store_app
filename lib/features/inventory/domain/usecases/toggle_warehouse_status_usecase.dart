import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/data/models/warehouse_model.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/warehouses_repository.dart';

@injectable
class ToggleWarehouseStatusUseCase {
  final WarehousesRepository repository;

  ToggleWarehouseStatusUseCase(this.repository);

  Future<void> call(WarehouseModel wh, bool isActive) async {
    return repository.toggleWarehouseStatus(wh, isActive);
  }
}
