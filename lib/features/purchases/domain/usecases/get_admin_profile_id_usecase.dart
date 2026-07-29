import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credits_repository.dart';

@lazySingleton
class GetAdminProfileIdUseCase {
  final SupplierCreditsRepository repository;

  GetAdminProfileIdUseCase(this.repository);

  Future<Either<Failure, String?>> call() {
    return repository.getAdminProfileId();
  }
}
