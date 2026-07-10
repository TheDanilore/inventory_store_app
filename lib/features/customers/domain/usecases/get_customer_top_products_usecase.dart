import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/features/customers/domain/entities/top_product_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/customers_repository.dart';

@lazySingleton
class GetCustomerTopProductsUseCase {
  final CustomersRepository repository;

  GetCustomerTopProductsUseCase(this.repository);

  Future<List<TopProductEntity>> call(String customerId) async {
    return await repository.getCustomerTopProducts(customerId);
  }
}

