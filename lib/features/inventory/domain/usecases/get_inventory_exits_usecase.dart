import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_exits_repository.dart';
import 'package:inventory_store_app/features/inventory/domain/entities/inventory_exit_entity.dart';

@injectable
class GetInventoryExitsUseCase {
  final InventoryExitsRepository repository;

  GetInventoryExitsUseCase(this.repository);

  Future<({List<InventoryExitEntity> data, int count})> call({
    required int start,
    required int end,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return repository.getExits(
      start: start,
      end: end,
      searchQuery: searchQuery,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
