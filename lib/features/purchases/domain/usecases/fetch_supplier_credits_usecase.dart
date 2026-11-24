import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credits_repository.dart';

@lazySingleton
class FetchSupplierCreditsUseCase {
  final SupplierCreditsRepository repository;

  FetchSupplierCreditsUseCase(this.repository);

  ({SupplierCreditsPageEntity data, bool isStale})? getCachedPage({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool withDebtOnly = false,
  }) {
    return repository.getCachedAccountsPage(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
      withDebtOnly: withDebtOnly,
    );
  }

  ({
    SupplierCreditsPageEntity data,
    String searchQuery,
    bool withDebtOnly,
    int page,
    int pageSize,
    bool isStale,
  })?
  getLatestSnapshot() {
    return repository.getLatestCachedSnapshot();
  }

  void invalidateCache() => repository.invalidateCache();

  Future<Either<Failure, SupplierCreditsPageEntity>> call({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool withDebtOnly = false,
    bool forceRefresh = false,
  }) {
    return repository.fetchAccountsPaginated(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
      withDebtOnly: withDebtOnly,
      forceRefresh: forceRefresh,
    );
  }
}
