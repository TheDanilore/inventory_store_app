import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credits_repository.dart';

@lazySingleton
class FetchSupplierCreditsUseCase {
  final SupplierCreditsRepository repository;

  FetchSupplierCreditsUseCase(this.repository);

  Future<
      Either<
          Failure,
          ({
            List<SupplierCreditEntity> accounts,
            int count,
            Map<String, dynamic> stats
          })>> call({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool withDebtOnly = false,
  }) {
    return repository.fetchAccountsPaginated(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
      withDebtOnly: withDebtOnly,
    );
  }
}

