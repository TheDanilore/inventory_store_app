import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credits_repository.dart';

@lazySingleton
class GetExistingCreditSupplierIdsUseCase {
  final SupplierCreditsRepository repository;

  GetExistingCreditSupplierIdsUseCase(this.repository);

  Future<Either<Failure, Set<String>>> call({
    String? excludeSupplierId,
  }) {
    return repository.getExistingCreditSupplierIds(
      excludeSupplierId: excludeSupplierId,
    );
  }
}

