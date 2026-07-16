import 'package:fpdart/fpdart.dart';
import 'package:inventory_store_app/core/errors/failure.dart';
import 'package:inventory_store_app/features/pos/domain/entities/cart_item_entity.dart';

abstract class CheckoutRepository {
  Future<Either<Failure, String>> processOrder({
    required String? customerId,
    required double totalAmount,
    required int pointsUsed,
    required int pointsEarned,
    required double totalProfit,
    required String? warehouseId,
    required List<CartItemEntity> itemsToBuy,
  });
  
  Future<Either<Failure, Map<String, dynamic>?>> fetchDefaultAddress(String profileId);
  Future<Either<Failure, Map<String, int>>> fetchStockForVariants(List<String> variantIds);
}
