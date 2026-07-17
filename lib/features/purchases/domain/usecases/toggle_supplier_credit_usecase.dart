import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credits_repository.dart';

@lazySingleton
class ToggleSupplierCreditUseCase {
  final SupplierCreditsRepository repository;

  ToggleSupplierCreditUseCase(this.repository);

  Future<Either<Failure, void>> call(String creditId, bool currentStatus) {
    return repository.toggleAccountStatus(creditId, currentStatus);
  }
}

