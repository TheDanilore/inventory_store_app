import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';

@injectable
class GetProfileByIdUc {
  final OrdersRepository repository;

  GetProfileByIdUc(this.repository);

  Future<Either<Failure, Map<String, dynamic>?>> call(String profileId) {
    return repository.getProfileById(profileId);
  }
}
