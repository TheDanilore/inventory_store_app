import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_repository.dart';

@injectable
class GetGeneralStockMetricsUseCase {
  final InventoryRepository _repository;

  GetGeneralStockMetricsUseCase(this._repository);

  Future<Map<String, dynamic>> call([String? warehouseId]) {
    return _repository.getGeneralStockMetrics(warehouseId: warehouseId);
  }
}
