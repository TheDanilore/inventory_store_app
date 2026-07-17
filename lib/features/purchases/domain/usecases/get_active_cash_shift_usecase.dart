import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credits_repository.dart';

@lazySingleton
class GetActiveCashShiftUseCase {
  final SupplierCreditsRepository repository;

  GetActiveCashShiftUseCase(this.repository);

  Future<Either<Failure, Map<String, dynamic>?>> call(String accountId) {
    return repository.getActiveCashShift(accountId);
  }
}

