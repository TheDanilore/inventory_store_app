import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credits_repository.dart';

@lazySingleton
class GetFinancialAccountsUseCase {
  final SupplierCreditsRepository repository;

  GetFinancialAccountsUseCase(this.repository);

  Future<Either<Failure, List<SupplierFinancialAccountOption>>> call() {
    return repository.getFinancialAccounts();
  }
}
