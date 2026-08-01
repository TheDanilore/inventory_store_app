import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/orders_repository.dart';

class RegisterCreditPaymentParams {
  final String? customerId;
  final String? creditId;
  final double amount;
  final String accountId;
  final String orderId;
  final String notes;
  final String? shiftId;

  RegisterCreditPaymentParams({
    required this.customerId,
    required this.creditId,
    required this.amount,
    required this.accountId,
    required this.orderId,
    required this.notes,
    required this.shiftId,
  });
}

@injectable
class RegisterCreditPaymentUc {
  final OrdersRepository repository;

  RegisterCreditPaymentUc(this.repository);

  Future<Either<Failure, void>> call(RegisterCreditPaymentParams params) {
    return repository.registerCreditPayment(
      customerId: params.customerId,
      creditId: params.creditId,
      amount: params.amount,
      accountId: params.accountId,
      orderId: params.orderId,
      notes: params.notes,
      shiftId: params.shiftId,
    );
  }
}
