import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/purchase_orders_repository.dart';

@lazySingleton
class GetPurchaseOrderFormCatalogsUseCase {
  final PurchaseOrdersRepository repository;

  GetPurchaseOrderFormCatalogsUseCase(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call({
    bool forceRefresh = false,
  }) {
    return repository.getFormCatalogs(forceRefresh: forceRefresh);
  }

  Map<String, dynamic>? getCached() => repository.getCachedFormCatalogs();
}
