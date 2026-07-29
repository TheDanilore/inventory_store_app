import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/catalog/domain/repositories/products_repository.dart';

@lazySingleton
class GetAdminFinancialDataUseCase {
  final ProductsRepository repository;

  GetAdminFinancialDataUseCase(this.repository);

  Future<Either<Failure, List<Map<String, dynamic>>>> call(String productId) {
    return repository.fetchAdminFinancialData(productId);
  }
}
