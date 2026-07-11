import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_exits_repository.dart';

@injectable
class GetExitItemsUseCase {
  final InventoryExitsRepository repository;

  GetExitItemsUseCase(this.repository);

  Future<List<dynamic>> call(String exitId) async {
    return repository.getExitItems(exitId);
  }
}
