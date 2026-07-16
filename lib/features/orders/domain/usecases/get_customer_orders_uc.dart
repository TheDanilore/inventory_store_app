import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';

import 'package:injectable/injectable.dart';

@injectable
class GetCustomerOrdersUc {
  final OrdersRepository repository;

  GetCustomerOrdersUc(this.repository);

  Future<Either<Failure, List<OrderEntity>>> call(String profileId, {int limit = 10, int offset = 0}) {
    return repository.getCustomerOrders(profileId, limit: limit, offset: offset);
  }
}
