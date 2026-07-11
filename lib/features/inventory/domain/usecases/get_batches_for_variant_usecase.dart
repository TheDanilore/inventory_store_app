import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_exits_repository.dart';

@injectable
class GetBatchesForVariantUseCase {
  final InventoryExitsRepository repository;

  GetBatchesForVariantUseCase(this.repository);

  Future<List<dynamic>> call(String variantId, String warehouseId) async {
    return repository.getBatchesForVariant(variantId, warehouseId);
  }
}
