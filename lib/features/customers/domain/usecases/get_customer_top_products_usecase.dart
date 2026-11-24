import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/customers/domain/entities/top_product_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/customers_repository.dart';

@lazySingleton
class GetCustomerTopProductsUseCase {
  final CustomersRepository repository;

  GetCustomerTopProductsUseCase(this.repository);

  Future<Either<Failure, List<TopProductEntity>>> call(String customerId) {
    return repository.getCustomerTopProducts(customerId);
  }
}
