import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/purchase_orders_repository.dart';

@lazySingleton
class FetchPurchaseOrdersUseCase {
  final PurchaseOrdersRepository repository;

  FetchPurchaseOrdersUseCase(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call({
    required int page,
    required int pageSize,
    String searchText = '',
    String statusFilter = 'Todos',
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return repository.fetchOrders(
      page: page,
      pageSize: pageSize,
      searchText: searchText,
      statusFilter: statusFilter,
      startDate: startDate,
      endDate: endDate,
    );
  }
}

