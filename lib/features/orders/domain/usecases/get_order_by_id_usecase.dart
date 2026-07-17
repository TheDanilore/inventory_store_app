import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';

@lazySingleton
class GetOrderByIdUseCase {
  final OrdersRepository repository;

  GetOrderByIdUseCase(this.repository);

  Future<Either<Failure, OrderEntity>> call(String orderId) {
    return repository.getOrderById(orderId);
  }
}
