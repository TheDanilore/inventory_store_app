import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/entities/order_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';
import 'package:injectable/injectable.dart';

class GetFilteredOrdersParams {
  final String? customerIdFilter;
  final String statusFilter;
  final String paymentStatusFilter;
  final DateTime? startDate;
  final DateTime? endDate;
  final String searchQuery;
  final int limit;
  final int offset;

  GetFilteredOrdersParams({
    this.customerIdFilter,
    required this.statusFilter,
    required this.paymentStatusFilter,
    this.startDate,
    this.endDate,
    required this.searchQuery,
    required this.limit,
    required this.offset,
  });
}

@lazySingleton
class GetFilteredOrdersUc {
  final OrdersRepository repository;

  GetFilteredOrdersUc(this.repository);

  Future<Either<Failure, ({List<OrderEntity> orders, int total})>> call(
      GetFilteredOrdersParams params) {
    return repository.getFilteredOrders(
      customerIdFilter: params.customerIdFilter,
      statusFilter: params.statusFilter,
      paymentStatusFilter: params.paymentStatusFilter,
      startDate: params.startDate,
      endDate: params.endDate,
      searchQuery: params.searchQuery,
      limit: params.limit,
      offset: params.offset,
    );
  }
}
