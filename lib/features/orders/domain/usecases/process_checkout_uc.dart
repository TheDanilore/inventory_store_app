import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';
import 'package:inventory_store_app/features/orders/domain/repositories/checkout_repository.dart';

import 'package:injectable/injectable.dart';

@injectable
class ProcessCheckoutUc {
  final CheckoutRepository repository;

  ProcessCheckoutUc(this.repository);

  Future<Either<Failure, String>> call({
    required String? customerId,
    required double totalAmount,
    required int pointsUsed,
    required int pointsEarned,
    required double totalProfit,
    required String? warehouseId,
    required List<CartItemEntity> itemsToBuy,
  }) {
    return repository.processOrder(
      customerId: customerId,
      totalAmount: totalAmount,
      pointsUsed: pointsUsed,
      pointsEarned: pointsEarned,
      totalProfit: totalProfit,
      warehouseId: warehouseId,
      itemsToBuy: itemsToBuy,
    );
  }
}
