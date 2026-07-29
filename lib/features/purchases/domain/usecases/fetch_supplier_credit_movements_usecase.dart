import 'package:injectable/injectable.dart';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_movement_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credit_movements_repository.dart';

@lazySingleton
class FetchSupplierCreditMovementsUseCase {
  final SupplierCreditMovementsRepository repository;

  FetchSupplierCreditMovementsUseCase(this.repository);

  Future<
    Either<
      Failure,
      ({
        List<SupplierCreditMovementEntity> movements,
        int totalCount,
        double totalCharged,
        double totalPaid,
      })
    >
  >
  call({
    required String creditId,
    required int page,
    required int pageSize,
    required MovementDateFilter dateFilter,
  }) {
    return repository.fetchMovementsPaginated(
      creditId: creditId,
      page: page,
      pageSize: pageSize,
      dateFilter: dateFilter,
    );
  }
}
