import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credits_repository.dart';

@lazySingleton
class GetPendingPurchaseOrdersTypedUseCase {
  final SupplierCreditsRepository repository;

  GetPendingPurchaseOrdersTypedUseCase(this.repository);

  Future<Either<Failure, List<PendingPurchaseOrderEntity>>> call(
    String supplierId,
  ) {
    return repository.getPendingPurchaseOrdersTyped(supplierId);
  }
}
