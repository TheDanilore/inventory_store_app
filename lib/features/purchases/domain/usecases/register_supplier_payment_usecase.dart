import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/core/usecases/usecase.dart';
import 'package:inventory_store_app/features/purchases/domain/entities/supplier_credit_entity.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/supplier_credits_repository.dart';

class RegisterSupplierPaymentParams {
  final String supplierId;
  final String creditId;
  final double amount;
  final String? accountId;
  final String? orderId;
  final String notes;
  final String? shiftId;
  final String? idempotencyKey;

  const RegisterSupplierPaymentParams({
    required this.supplierId,
    required this.creditId,
    required this.amount,
    required this.accountId,
    required this.orderId,
    required this.notes,
    required this.shiftId,
    this.idempotencyKey,
  });
}

@lazySingleton
class RegisterSupplierPaymentUseCase
    implements UseCase<SupplierCreditEntity?, RegisterSupplierPaymentParams> {
  final SupplierCreditsRepository repository;

  RegisterSupplierPaymentUseCase(this.repository);

  @override
  Future<Either<Failure, SupplierCreditEntity?>> call(
    RegisterSupplierPaymentParams params,
  ) {
    return repository.registerPayment(
      supplierId: params.supplierId,
      creditId: params.creditId,
      amount: params.amount,
      accountId: params.accountId,
      orderId: params.orderId,
      notes: params.notes,
      shiftId: params.shiftId,
      idempotencyKey: params.idempotencyKey,
    );
  }
}
