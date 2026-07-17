import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/purchase_orders_repository.dart';

@lazySingleton
class UpdatePurchaseOrderStatusUseCase {
  final PurchaseOrdersRepository repository;

  UpdatePurchaseOrderStatusUseCase(this.repository);

  Future<Either<Failure, void>> call(String poId, String status) {
    return repository.updateOrderStatus(poId, status);
  }
}

