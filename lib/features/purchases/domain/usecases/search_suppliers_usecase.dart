import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credits_repository.dart';

@lazySingleton
class SearchSuppliersUseCase {
  final SupplierCreditsRepository repository;

  SearchSuppliersUseCase(this.repository);

  Future<Either<Failure, List<Map<String, dynamic>>>> call(
    String query,
    Set<String> existingSupplierIds,
  ) {
    return repository.searchSuppliers(query, existingSupplierIds);
  }
}

