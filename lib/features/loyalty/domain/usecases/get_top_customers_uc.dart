import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/loyalty/domain/repositories/loyalty_repository.dart';
import 'package:inventory_store_app/features/customers/domain/entities/customer_entity.dart';

@lazySingleton
class GetTopCustomersUC {
  final LoyaltyRepository repository;

  GetTopCustomersUC(this.repository);

  Future<Either<Failure, List<CustomerEntity>>> call(int limit) async {
    return await repository.getTopCustomers(limit);
  }
}
