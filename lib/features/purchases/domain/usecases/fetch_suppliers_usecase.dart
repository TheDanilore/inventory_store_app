import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/suppliers_repository.dart';

@lazySingleton
class FetchSuppliersUseCase {
  final SuppliersRepository repository;

  FetchSuppliersUseCase(this.repository);

  Future<Either<Failure, ({List<SupplierEntity> suppliers, int totalCount})>>
      call({
    required int page,
    required int pageSize,
    String searchQuery = '',
  }) {
    return repository.fetchSuppliers(
      page: page,
      pageSize: pageSize,
      searchQuery: searchQuery,
    );
  }
}

