import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';

import 'package:injectable/injectable.dart';

@injectable
class GetOrderDetailsUc {
  final OrdersRepository repository;

  GetOrderDetailsUc(this.repository);

  Future<Either<Failure, OrderDetailsResult>> call(String orderId) async {
    final orderRes = await repository.getOrderById(orderId);
    return orderRes.fold((failure) => Left(failure), (order) async {
      final itemsRes = await repository.getOrderItems(orderId);
      return itemsRes.fold(
        (failure) => Left(failure),
        (items) => Right(OrderDetailsResult(order: order, items: items)),
      );
    });
  }
}

class OrderDetailsResult {
  final OrderEntity order;
  final List<OrderItemEntity> items;

  OrderDetailsResult({required this.order, required this.items});
}
