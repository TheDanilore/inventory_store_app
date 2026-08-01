import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/purchase_orders_repository.dart';

@injectable
class GetPurchaseOrderByIdUseCase {
  final PurchaseOrdersRepository _repository;

  GetPurchaseOrderByIdUseCase(this._repository);

  Future<Either<Failure, Map<String, dynamic>?>> call(String poId) {
    return _repository.getPurchaseOrderById(poId);
  }
}
