import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/purchase_order_item_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/purchase_orders_repository.dart';

@lazySingleton
class FetchPurchaseOrderItemsUseCase {
  final PurchaseOrdersRepository repository;

  FetchPurchaseOrderItemsUseCase(this.repository);

  Future<Either<Failure, List<PurchaseOrderItemEntity>>> call(
    String poId, {
    bool forceRefresh = false,
  }) {
    return repository.fetchOrderItems(poId, forceRefresh: forceRefresh);
  }

  /// Retorno síncrono desde la memoria L1 (0ms) para Zero-Shimmer (Frame-0).
  List<PurchaseOrderItemEntity>? getCached(String poId) =>
      repository.getCachedOrderItems(poId);
}
