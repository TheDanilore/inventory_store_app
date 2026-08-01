import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_item_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';

class ProcessReturnParams {
  final String orderId;
  final List<OrderItemEntity> items;
  final String? currentProfileId;
  final String? notesOverride;

  ProcessReturnParams({
    required this.orderId,
    required this.items,
    this.currentProfileId,
    this.notesOverride,
  });
}

@lazySingleton
class ProcessReturnUc {
  final OrdersRepository repository;

  ProcessReturnUc(this.repository);

  Future<Either<Failure, void>> call(ProcessReturnParams params) {
    return repository.processReturn(
      orderId: params.orderId,
      items: params.items,
      currentProfileId: params.currentProfileId,
      notesOverride: params.notesOverride,
    );
  }
}
