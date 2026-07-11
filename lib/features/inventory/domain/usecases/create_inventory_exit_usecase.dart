import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_exits_repository.dart';

@injectable
class CreateInventoryExitUseCase {
  final InventoryExitsRepository repository;

  CreateInventoryExitUseCase(this.repository);

  Future<void> call({
    required String warehouseId,
    required String reason,
    required String? notes,
    required String? createdByProfileId,
    required List<dynamic> items,
  }) async {
    return repository.saveExitTransaction(
      warehouseId: warehouseId,
      reason: reason,
      notes: notes,
      createdByProfileId: createdByProfileId,
      items: items,
    );
  }
}
