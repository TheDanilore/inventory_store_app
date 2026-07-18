import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credits_repository.dart';

@lazySingleton
class SaveSupplierCreditUseCase {
  final SupplierCreditsRepository repository;

  SaveSupplierCreditUseCase(this.repository);

  Future<Either<Failure, void>> call({
    required String? creditId,
    required String supplierId,
    required double creditLimit,
    String? adminProfileId,
  }) {
    return repository.saveAccount(
      creditId: creditId,
      supplierId: supplierId,
      creditLimit: creditLimit,
      adminProfileId: adminProfileId,
    );
  }
}
