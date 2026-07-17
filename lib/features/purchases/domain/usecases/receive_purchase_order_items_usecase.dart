import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/purchase_orders_repository.dart';

@lazySingleton
class ReceivePurchaseOrderItemsUseCase {
  final PurchaseOrdersRepository repository;

  ReceivePurchaseOrderItemsUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String poId,
    required List<Map<String, dynamic>> receivedItems,
    required String warehouseId,
  }) {
    return repository.receiveOrderItems(
      poId: poId,
      receivedItems: receivedItems,
      warehouseId: warehouseId,
    );
  }
}

