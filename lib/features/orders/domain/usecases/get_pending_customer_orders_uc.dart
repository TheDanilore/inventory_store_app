import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';

@injectable
class GetPendingCustomerOrdersUc {
  final OrdersRepository _repository;

  GetPendingCustomerOrdersUc(this._repository);

  Future<Either<Failure, List<OrderEntity>>> call(String customerId) async {
    return await _repository.getPendingOrdersByCustomer(customerId);
  }
}
