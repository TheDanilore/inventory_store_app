import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';
import 'package:injectable/injectable.dart';

@injectable
class WatchPendingOrdersCountUc {
  final OrdersRepository repository;
  WatchPendingOrdersCountUc(this.repository);
  Stream<Either<Failure, int>> call() {
    return repository.watchPendingOrdersCount();
  }
}
