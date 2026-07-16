import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/checkout_repository.dart';

import 'package:injectable/injectable.dart';

@injectable
class VerifyStockUc {
  final CheckoutRepository repository;

  VerifyStockUc(this.repository);

  Future<Either<Failure, Map<String, int>>> call(List<String> variantIds) {
    return repository.fetchStockForVariants(variantIds);
  }
}
