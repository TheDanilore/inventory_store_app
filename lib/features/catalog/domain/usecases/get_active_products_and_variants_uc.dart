import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';

@injectable
class GetActiveProductsAndVariantsUseCase {
  final ProductsRepository repository;

  GetActiveProductsAndVariantsUseCase(this.repository);

  Future<Map<String, dynamic>> call() async {
    final result = await repository.getActiveProductsAndVariants();
    return result.fold(
      (failure) => throw Exception(failure.message),
      (data) => data,
    );
  }
}
