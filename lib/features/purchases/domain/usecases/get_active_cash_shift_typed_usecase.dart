import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credits_repository.dart';

@lazySingleton
class GetActiveCashShiftTypedUseCase {
  final SupplierCreditsRepository repository;

  GetActiveCashShiftTypedUseCase(this.repository);

  Future<Either<Failure, ActiveCashShiftEntity?>> call(String accountId) {
    return repository.getActiveCashShiftTyped(accountId);
  }
}
