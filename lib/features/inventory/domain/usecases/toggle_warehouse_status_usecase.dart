import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/warehouse_entity.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/warehouses_repository.dart';

@injectable
class ToggleWarehouseStatusUseCase {
  final WarehousesRepository repository;

  ToggleWarehouseStatusUseCase(this.repository);

  Future<void> call(WarehouseEntity wh, bool isActive) async {
    return repository.toggleWarehouseStatus(wh, isActive);
  }
}
