import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/purchase_orders_repository.dart';

class RegisterOrderPaymentParams {
  final String orderId;
  final String supplierId;
  final double amount;
  final String accountId;
  final String? shiftId;

  RegisterOrderPaymentParams({
    required this.orderId,
    required this.supplierId,
    required this.amount,
    required this.accountId,
    required this.shiftId,
  });
}

@lazySingleton
class RegisterOrderPaymentUseCase {
  final PurchaseOrdersRepository repository;

  RegisterOrderPaymentUseCase(this.repository);

  Future<Either<Failure, void>> call(RegisterOrderPaymentParams params) async {
    return repository.registerOrderPayment(
      orderId: params.orderId,
      supplierId: params.supplierId,
      amount: params.amount,
      accountId: params.accountId,
      shiftId: params.shiftId,
    );
  }
}
