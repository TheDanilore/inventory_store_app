import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_repository.dart';

@injectable
class GetGeneralStockMetricsUseCase {
  final InventoryRepository _repository;

  GetGeneralStockMetricsUseCase(this._repository);

  Future<Map<String, dynamic>> call(NoParams params) {
    return _repository.getGeneralStockMetrics();
  }
}
