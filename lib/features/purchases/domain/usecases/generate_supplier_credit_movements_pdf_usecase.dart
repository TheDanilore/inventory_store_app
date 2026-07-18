import 'package:injectable/injectable.dart';
import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_movement_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credit_movements_repository.dart';

@lazySingleton
class GenerateSupplierCreditMovementsPdfUseCase {
  final SupplierCreditMovementsRepository repository;

  GenerateSupplierCreditMovementsPdfUseCase(this.repository);

  Future<Either<Failure, Uint8List>> call({
    required String supplierName,
    required List<SupplierCreditMovementEntity> allMovementsForPdf,
  }) {
    return repository.generateMovementsPdf(
      supplierName: supplierName,
      allMovementsForPdf: allMovementsForPdf,
    );
  }
}
