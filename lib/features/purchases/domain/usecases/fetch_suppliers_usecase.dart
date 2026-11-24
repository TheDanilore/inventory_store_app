import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/suppliers_repository.dart';

@lazySingleton
class FetchSuppliersUseCase {
  final SuppliersRepository repository;

  FetchSuppliersUseCase(this.repository);

  ({SuppliersPageEntity data, bool isStale})? getCachedPage({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool? filterIsActive,
  }) {
    return repository.getCachedSuppliersPage(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
      filterIsActive: filterIsActive,
    );
  }

  ({
    SuppliersPageEntity data,
    String searchQuery,
    bool? filterIsActive,
    int page,
    int pageSize,
    bool isStale,
  })?
  getLatestSnapshot() {
    return repository.getLatestCachedSnapshot();
  }

  Future<Either<Failure, SuppliersPageEntity>> call({
    required int page,
    required int pageSize,
    String searchQuery = '',
    bool? filterIsActive,
    bool forceRefresh = false,
  }) {
    return repository.fetchSuppliers(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
      filterIsActive: filterIsActive,
      forceRefresh: forceRefresh,
    );
  }
}
