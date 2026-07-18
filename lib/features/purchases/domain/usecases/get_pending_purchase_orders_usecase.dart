import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credits_repository.dart';

@lazySingleton
class GetPendingPurchaseOrdersUseCase {
  final SupplierCreditsRepository repository;

  GetPendingPurchaseOrdersUseCase(this.repository);

  Future<Either<Failure, List<Map<String, dynamic>>>> call(String supplierId) {
    return repository.getPendingPurchaseOrders(supplierId);
  }
}
