import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_movement_entity.dart';
import 'dart:typed_data';

enum MovementDateFilter { allTime, thisMonth, lastMonth }

abstract class SupplierCreditMovementsRepository {
  Future<
      Either<
          Failure,
          ({
            List<SupplierCreditMovementEntity> movements,
            int totalCount,
            double totalCharged,
            double totalPaid,
          })>> fetchMovementsPaginated({
    required String creditId,
    required int page,
    required int pageSize,
    required MovementDateFilter dateFilter,
  });

  Future<Either<Failure, Uint8List>> generateMovementsPdf({
    required String supplierName,
    required List<SupplierCreditMovementEntity> allMovementsForPdf,
  });
}
