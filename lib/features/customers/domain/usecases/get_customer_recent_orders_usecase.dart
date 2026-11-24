import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/customers/domain/entities/recent_order_entity.dart';
import 'package:inventory_store_app/features/customers/domain/repositories/customers_repository.dart';

@lazySingleton
class GetCustomerRecentOrdersUseCase {
  final CustomersRepository repository;

  GetCustomerRecentOrdersUseCase(this.repository);

  Future<Either<Failure, List<RecentOrderEntity>>> call(String customerId) {
    return repository.getCustomerRecentOrders(customerId);
  }
}
