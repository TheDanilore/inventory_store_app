import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/inventory/domain/repositories/inventory_repository.dart';

@injectable
class GetCategoriesUseCase {
  final InventoryRepository _repository;

  GetCategoriesUseCase(this._repository);

  Future<List<String>> call(NoParams params) {
    return _repository.getCategories();
  }
}
