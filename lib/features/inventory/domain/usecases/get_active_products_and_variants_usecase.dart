import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_exits_repository.dart';

@injectable
class GetActiveProductsAndVariantsUseCase {
  final InventoryExitsRepository repository;

  GetActiveProductsAndVariantsUseCase(this.repository);

  Future<Map<String, dynamic>> call() async {
    return repository.getActiveProductsAndVariants();
  }
}
