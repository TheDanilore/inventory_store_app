import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';
import 'package:injectable/injectable.dart';

class UpdateOrderStatusParams {
  final OrderEntity order;
  final String newStatus;
  final String? currentProfileId;

  UpdateOrderStatusParams({
    required this.order,
    required this.newStatus,
    required this.currentProfileId,
  });
}

@lazySingleton
class UpdateOrderStatusUc {
  final OrdersRepository repository;

  UpdateOrderStatusUc(this.repository);

  Future<Either<Failure, void>> call(UpdateOrderStatusParams params) async {
    return await repository.updateOrderStatus(
      order: params.order,
      newStatus: params.newStatus,
      currentProfileId: params.currentProfileId,
    );
  }
}
