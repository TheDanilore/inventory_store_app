import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class GetOrderItemsUc {
  final OrdersRepository repository;

  GetOrderItemsUc(this.repository);

  Future<Either<Failure, List<OrderItemEntity>>> call(String orderId) {
    return repository.getOrderItems(orderId);
  }
}
