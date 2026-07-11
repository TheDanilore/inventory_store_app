import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_repository.dart';

@injectable
class GetBatchMetricsUseCase {
  final InventoryRepository _repository;

  GetBatchMetricsUseCase(this._repository);

  Future<Map<String, int>> call({String search = ''}) {
    return _repository.getBatchMetrics(search: search);
  }
}
