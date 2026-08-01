import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/purchase_orders_repository.dart';

@lazySingleton
class GetSupplierCreditUseCase {
  final PurchaseOrdersRepository repository;

  GetSupplierCreditUseCase(this.repository);

  Future<Either<Failure, Map<String, dynamic>?>> call(String supplierId) {
    return repository.getSupplierCredit(supplierId);
  }
}
