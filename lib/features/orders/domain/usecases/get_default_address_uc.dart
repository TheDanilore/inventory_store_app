import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/checkout_repository.dart';

import 'package:injectable/injectable.dart';

@injectable
class GetDefaultAddressUc {
  final CheckoutRepository repository;

  GetDefaultAddressUc(this.repository);

  Future<Either<Failure, Map<String, dynamic>?>> call(String profileId) {
    return repository.fetchDefaultAddress(profileId);
  }
}
