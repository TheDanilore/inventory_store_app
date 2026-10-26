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
    final results = await Future.wait([
      repository.getOrderById(orderId),
      repository.getOrderItems(orderId),
    ]);

    final orderRes = results[0] as Either<Failure, OrderEntity>;
    final itemsRes = results[1] as Either<Failure, List<OrderItemEntity>>;

    return orderRes.fold(
      (failure) => Left(failure),
      (order) => itemsRes.fold(
        (failure) => Left(failure),
        (items) => Right(OrderDetailsResult(order: order, items: items)),
      ),
    );
  }
}

class OrderDetailsResult {
  final OrderEntity order;
  final List<OrderItemEntity> items;

  OrderDetailsResult({required this.order, required this.items});
}
