import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';
import 'package:injectable/injectable.dart';

class CancelOrderParams {
  final String orderId;
  final String? customerId;
  final String? currentProfileId;
  final String? notesOverride;

  CancelOrderParams({
    required this.orderId,
    this.customerId,
    this.currentProfileId,
    this.notesOverride,
  });
}

@lazySingleton
class CancelOrderUc {
  final OrdersRepository repository;

  CancelOrderUc(this.repository);

  Future<Either<Failure, void>> call(CancelOrderParams params) {
    return repository.cancelOrder(
      orderId: params.orderId,
      customerId: params.customerId,
      currentProfileId: params.currentProfileId,
      notesOverride: params.notesOverride,
    );
  }
}
