import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';

@injectable
class CheckActiveCashShiftUc {
  final OrdersRepository repository;

  CheckActiveCashShiftUc(this.repository);

  Future<Either<Failure, bool>> call() {
    return repository.checkActiveCashShift();
  }
}
