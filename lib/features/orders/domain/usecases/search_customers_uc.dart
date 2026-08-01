import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';

@injectable
class SearchCustomersUc {
  final OrdersRepository repository;

  SearchCustomersUc(this.repository);

  Future<Either<Failure, List<Map<String, dynamic>>>> call(String query) {
    return repository.searchCustomers(query);
  }
}
