import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/purchases/domain/repositories/purchase_orders_repository.dart';

class UpdateOrderPaymentMethodParams {
  final String orderId;
  final String supplierId;
  final String newMethod;
  final String oldMethod;
  final double orderAmount;

  UpdateOrderPaymentMethodParams({
    required this.orderId,
    required this.supplierId,
    required this.newMethod,
    required this.oldMethod,
    required this.orderAmount,
  });
}

@lazySingleton
class UpdateOrderPaymentMethodUseCase {
  final PurchaseOrdersRepository repository;

  UpdateOrderPaymentMethodUseCase(this.repository);

  Future<Either<Failure, void>> call(
    UpdateOrderPaymentMethodParams params,
  ) async {
    return repository.updateOrderPaymentMethod(
      orderId: params.orderId,
      supplierId: params.supplierId,
      newMethod: params.newMethod,
      oldMethod: params.oldMethod,
      orderAmount: params.orderAmount,
    );
  }
}
